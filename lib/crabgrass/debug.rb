##
## Handy tools for debugging.
## see doc/DEBUGGING for more info.
##

# set envirenment variable SHOWLOGS to log sql commands to stdout.
ActiveRecord::Base.logger = Logger.new(STDOUT) if ENV['SHOWLOGS'].present?

# here is a handy method for dev mode. it dumps a table to a yml file.
# you can use it to build up your fixtures. dumps to
# test/fixtures/dumped_tablename.yml
def export_yml(table_name)
  sql = 'SELECT * FROM %s'
  i = '000'
  File.open(Rails.root + "test/fixtures/dumped_#{table_name}.yml", 'w') do |file|
    data = ActiveRecord::Base.connection.select_all(sql % table_name)
    file.write data.each_with_object({}) { |record, hash|
      hash["#{table_name}_#{i.succ!}"] = record
    }.to_yaml
  end
end

#
# have you ever wanted to know what part of your code was triggering a particular
# sql query? set the STOP_ON_SQL environment variable to find out.
#
# For example:
#
# export STOP_ON_SQL='SELECT * FROM `users` WHERE (`users`.`id` = 633)'
# script/server
#
module LogWithDebug

    def log(sql, name, &block)
      if sql.match(STOP_ON_SQL_MATCH)
        debugger
        true
      end
      super(sql, name, &block)
    end
end


if ENV['STOP_ON_SQL'].present?
  STOP_ON_SQL_MATCH = Regexp.escape(ENV['STOP_ON_SQL']).gsub(/\\\s+/, '\s+')
  class ActiveRecord::ConnectionAdapters::AbstractAdapter
    prepend LogWithDebug
  end
end

module CallWithDebug

    def call(*args, &block)
      @@active_record_callbacks ||= Hash[@@debug_callbacks.collect do |callback|
        methods = ActiveRecord::Base.send("#{callback}_callback_chain").collect(&:method)
        [callback, methods]
      end]

      if should_run_callback?(*args) and method.is_a?(Symbol) and @@debug_callbacks.include?(kind) and !@@active_record_callbacks[kind].include?(method)
        puts "++++ #{kind} #{'+' * 60}" if @@last_kind != kind
        puts "---- #{method} ----"
        @@last_kind = kind
      end
      call(*args, &block)
    end
end

#
# Debugging activerecord callbacks.
#

if ENV['DEBUG_CALLBACKS'].present?
  #
  # if enabled, this will print out when each callback gets called.
  #
  class ActiveSupport::Callbacks::Callback

    prepend CallWithDebug

    @@last_kind = nil

    @@debug_callbacks = %i[before_validation before_validation_on_create after_validation
                           after_validation_on_create before_save before_create after_create after_save]

    @@active_record_callbacks = nil

  end

  # this is most useful in combination with ActiveRecord::Base.logger = Logger.new(STDOUT)
  ActiveRecord::Base.logger = Logger.new(STDOUT)
end
