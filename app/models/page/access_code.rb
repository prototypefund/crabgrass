#
#  Page Access Code
#
#  Two uses:
#  (1) provide url obfuscation for links in email
#  (2) or, to give url or url+email access to a page
#

require 'password'

class Page::AccessCode < ApplicationRecord
  self.table_name = 'page_access_codes'

  belongs_to :user
  belongs_to :page

  before_create :set_unique_code
  before_create :set_expiry

  def set_unique_code
    begin
      self.code = Password.random(10)
    end until self.class.find_by_code(code).nil?
  end

  def set_expiry
    self.expires_at ||= Time.now + 30.days
  end

  def expired?
    self.expires_at <= Time.now.utc
  end

  def self.cleanup_expired
    where('expires_at < ?', Time.now.utc).delete_all
  end

  def days_left
    ((expires_at - Time.now) / 1.day).ceil
  end

  def to_param
    code
  end
end
