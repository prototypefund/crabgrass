module PageRecords
  def own_page(type = nil, options = {})
    if type.is_a? Hash
      options = type
      type = nil
    end
    options[:created_by] = user
    page = new_page(type, options)
    save_and_index(page)
  end

  def public_page(options = {})
    options[:public] = true
    page = new_page options
    save_and_index(page)
  end

  def with_page(types)
    assert_for_all types do |type|
      yield new_page(type)
    end
  end

  def new_page(type = nil, options = {})
    if type.is_a? Hash
      options = type
      type = nil
    end
    page_options = options.slice :title,
      :summary,
      :created_by,
      :owner,
      :flow,
      :public
    page_options[:created_at] = Time.now
    page_options[:updated_at] = Time.now
    if type
      @page = records[type] ||= FactoryBot.build(type, page_options)
    else
      @page ||= FactoryBot.build(:discussion_page, page_options)
    end
  end

  def prepare_page(type, options = {})
    type_name = I18n.t "#{type}_display"
    # create page is on a hidden dropdown
    # click_on :create_page.t
    visit '/pages/create/me'
    click_on type_name
    new_page(type, options)
    # let's make it easy to tell which page type we are testing
    new_page.title = "#{type} - #{new_page.title}"
    fill_in_new_page_form(type, options)
  end

  def create_page(type, options = {})
    if type.is_a? Hash
      options = type
      type = :discussion_page
    end
    prepare_page(type, options)
    click_on :create.t
  end

  def fill_in_new_page_form(type, options)
    title = options[:title] || new_page.title
    file = options[:file] || fixture_file('bee.jpg')
    try_to_fill_in :title.t,      with: title
    try_to_fill_in :summary.t,    with: new_page.summary
    click_on 'Additional Access'
    try_to_attach_file :asset_uploaded_data, file
    # workaround for having the right page title in the test record
    if type == :asset_page
      new_page.title = file.basename(file.extname).to_s.nameize
    end
  end

  def save_and_index(page)
    page.save! if page.new_record?
    page
  end
end
