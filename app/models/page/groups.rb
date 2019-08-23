#
# Page relationship to Groups
#
module Page::Groups
  def self.included(base)
    base.extend(ClassMethods)
    base.instance_eval do
      has_many :group_participations,
               class_name: 'Group::Participation',
               dependent: :destroy,
               inverse_of: :page,
               autosave: true
      has_many :groups, through: :group_participations
    end
  end

  def self.for_group(group)
    ids = Group.namespace_ids(group.id)
    joins(:group_participations)
      .where(group_participations: { group_id: ids })
  end

  # returns the owner if the owner happens to be a group
  def group
    owner if owner and owner.is_a? Group
  end

  # When getting a list of ids of groups for this page,
  # we use group_participations. This way, we will have
  # current data even if a group is added and the page
  # has not yet been saved.
  def group_ids
    group_participations.collect(&:group_id)
  end

  # returns an array of group ids that compose this page's namespace
  # includes direct groups and all the relatives of the direct groups.
  def namespace_group_ids
    Group.namespace_ids(group_ids)
  end

  def namespace_group_ids_sql
    namespace_group_ids.any? ? namespace_group_ids.join(',') : 'NULL'
  end

  # takes an array of group ids, return all the matching group participations
  # this is called a lot, since it is used to determine permission for the page
  def participation_for_groups(group_ids)
    group_participations.collect do |gpart|
      gpart if group_ids.include? gpart.group_id
    end.compact
  end

  def participation_for_group(group)
    group_participations.detect { |gpart| gpart.group_id == group.id }
  end

  # a list of the group participation objects, but sorted
  # by access (higher number is less access permissions)
  def sorted_group_participations
    group_participations.sort do |a, b|
      (a.access || 100) <=> (b.access || 100)
    end
  end

  def shared_with_all?
    site.try.network and
      !participation_for_group(site.try.network).nil?
  end

  # FIXME: remove method as elijah suggests
  #
  # returns all the groups with a particular access level
  # - use option :all for all the accesslevels
  # --
  #   TODO
  #   what is the purpose of this method?
  #
  #   i think it can be removed.
  #
  #   also, page.groups_with_access(:all) will always be equal to page.groups
  #   groups don't have a group_participation record unless they have been
  #   granted access (unlike user_participation records)
  #
  #   -elijah
  # --
  #
  def groups_with_access(access)
    group_participations.collect do |gpart|
      if access == :all
        gpart.group if ACCESS.include?(gpart.access)
      else
        gpart.group if gpart.access == ACCESS[access]
      end
    end.compact
  end

  module ClassMethods
    #
    # returns an array of the number of pages in each month for a particular group.
    # (based on what pages the current_user can see)
    #
    def month_counts(options)
      field = case options[:field]
              when 'created' then 'created_at'
              when 'updated' then 'updated_at'
              else 'error'
      end

      sql = "SELECT MONTH(pages.#{field}) AS month, YEAR(pages.#{field}) AS year, count(pages.id) as page_count "
      sql += 'FROM pages JOIN page_terms ON pages.id = page_terms.page_id '
      sql += format("WHERE MATCH(page_terms.access_ids,page_terms.tags) AGAINST ('%s' IN BOOLEAN MODE) AND page_terms.flow IS NULL ", access_filter(options))
      sql += 'GROUP BY year, month ORDER BY year, month'
      Page.connection.select_all(sql)
    end
  end
end
