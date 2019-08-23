#
#
# FULLTEXT SEARCHING and PERMISSIONS
#
# Here in lies the code for supporting full text indexing of pages, to be
# used by sphinx and mysql fulltext index. See crabgrass_plugins/crabgrass_path_finder for how this is actually searched.
#
#
module Page::Index
  extend ActiveSupport::Concern

  include ActiveSupport::Benchmarkable

  included do
    has_one :page_terms,
            class_name: 'Page::Terms',
            dependent: :destroy
    before_save :update_page_terms_in_background
  end

  module ClassMethods
    # returns the an array of group and user ids, but transformed.
    # this transformation is neccessary for sphinx (so that group ids
    # and user ids are in the same attribute) and for mysql fulltext
    # (where terms must be at least 4 characters long).
    #
    # When stored in sphinx, these are converted to numbers. When stored
    # in mysql, these are stored as strings.
    #
    # for example:
    #   access_ids_for(:public => true, :group_ids => [1,2,3000], :user_ids => [4,5,6000])
    # returns:
    #   ["0001", "0081", "0082", "83000", "0014", "0015", "16000"]
    #
    # The rules:
    #
    #  * pad with 0 to at least 4 chars.
    #  * prefix user ids with 1
    #  * prefix group ids with 8
    #  * 0001 means the page is marked public.
    #
    def access_ids_for(args = {})
      id_array = []
      id_array += ['0001'] if args[:public]
      id_array += args[:group_ids].collect { |id| encode_group_id(id) } if args[:group_ids]
      id_array += args[:user_ids].collect  { |id| encode_user_id(id) } if args[:user_ids]
      id_array
    end

    def encode_user_id(id)
      format('%04d', "1#{id}")
    end

    def encode_group_id(id)
      format('%04d', "8#{id}")
    end

    # converts a tag list array into a tag list array suitable for searching a
    # fulltext index.
    #
    # The rules:
    #
    #  * The tag must be CGI url escaped so that special characters are not in the
    #    fulltext index. The fulltext matching does not work on characters like
    #    !@#$%^&()=*.
    #  * space, '+', and '.' are not allowed, we replace with '_'. (The +
    #    character is not allowed since this is how CGI.escape encodes spaces).
    #  * The character % is not allowed, so we replace it with 'QQ'. This is not
    #    ideal, but it seems sufficiently unlikely that someone will tag something
    #    QQ.
    #  * The tag must be at least four characters in length for the fulltext index
    #    to work, so we pad with _ if necessary.
    #  * The tag must not be numeric, so we prefix with _ if the tag is a number.
    #
    # example:
    #   ['blue fish', 'tv',   '12',   '1234',  'café'] =>
    #   ['blue_fish', '__tv', '__12', '_1234', 'cafQQC3QQA9']
    #
    def searchable_tag_list(tags)
      tags.map do |s|
        s = s.gsub(/[\s\.\+]/, '_') # characters that should be skipped by CGI.escape
        s = CGI.escape(s)
        s = s.gsub('%', 'QQ')
        format('%4s', s).gsub(/\s|^(\d)/, '_\1')
      end
    end

    # this is not thread safe.
    def with_deltas_disabled
      if block_given?
        previous_deltas_enabled = ThinkingSphinx.deltas_enabled?
        begin
          ThinkingSphinx.deltas_enabled = false
          yield
        ensure
          ThinkingSphinx.deltas_enabled = previous_deltas_enabled
        end
      end
    end
  end

  def update_page_terms_in_background
    if false # backgroundrb_running?
      ## ^^^ I have disabled background updating of page terms for two reasons:
      ## (1) it doesn't seem to be working right now, and i have no idea why
      ## (2) the delta index is fast enough without running in the background.
      begin
        # first, immediately update access, because that needs to always be up to date.
        Page.with_deltas_disabled do
          terms = (page_terms || create_page_terms)
          PageTerms.update_all(format("access_ids = '%s'", access_ids), format('id = %i', terms.id))
        end
        # fire off background task
        MiddleMan.worker(:indexing_worker).async_update_page_terms(arg: id)
      rescue BackgrounDRb::NoServerAvailable => err
        Rails.logger.error "Warning: #{err}; performing synchronous update of page index"
        update_page_terms
      end
    else
      benchmark 'Page#update_page_terms' do
        update_page_terms
      end
    end
  end

  def update_page_terms
    terms = (self.page_terms ||= build_page_terms)

    # attributes
    %w[updated_at created_at created_by_id updated_by_id
       created_by_login updated_by_login owner_name resolved
       flow contributors_count stars_count].each do |field|
      terms.send("#{field}=", send(field))
    end

    # text
    terms.title     = title.capitalize + ' ' + tag_list.join(' ')
    terms.title = terms.title[0..189]
    # ^^ start with capital letter for sorting
    terms.tags      = Page.searchable_tag_list(tag_list).join(' ')
    terms.body      = summary_terms + ' ' + body_terms
    terms.comments  = comment_terms

    # meta
    terms.page_type = type
    terms.media = media_flags

    # access control
    terms.access_ids = access_ids
    terms.owner_id = if owner_type == 'User'
                       Page.encode_user_id(owner_id)
                     else
                       Page.encode_group_id(owner_id)
                     end

    # additional hook for subclasses
    custom_page_terms(terms)

    begin
      terms.save! if !new_record? and terms.changed?
    rescue => exception
      # page terms sometimes cause mysql exceptions
      # We still need the surrounding context to continue to work.
      # So we won't reraise here.
      Rails.logger.error "ERROR - investigate me!"
      Rails.logger.error "Failed to update page terms: #{terms.id} for page: #{id}."
      Rails.logger.error exception
    end
  end

  # :nodoc:
  def access_ids
    Page.access_ids_for(
      public: public?,
      group_ids: group_ids,
      user_ids: user_ids
    ).join(' ')
  end

  # Converts the boolean media flags to an array of integers
  # page.is_image? -> [1]
  def media_flags
    ret = []
    ret << MEDIA_TYPE[:audio] if is_audio?
    ret << MEDIA_TYPE[:video] if is_video?
    ret << MEDIA_TYPE[:image] if is_image?
    ret << MEDIA_TYPE[:document] if is_document?
    ret
  end

  # Returns the text to be included in the body of the page index.
  # Subclasses of Page should override this method as appropriate.
  # For example WikiPage should return wiki.body, and TaskListPage
  # will merge all of the tasks associated with it.
  # Defaults to empty string.
  def body_terms
    ''
  end

  # Returns text that should be weighted low.
  # Defaults to all the comments, but can be overriden by the page subclass.
  def comment_terms
    discussion ? discussion.posts.visible.includes(:user).to_a * "\n" : ''
  end

  # Returns the text that should be included with the body in the page index.
  # Defaults to the page name, title, and summary.
  def summary_terms
    [name, title, summary].join("\n")
  end

  # to be overriden by subclasses
  def custom_page_terms(terms) end
end
