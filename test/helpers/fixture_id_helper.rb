module FixtureIdHelper
  delegate :identify, to: ActiveRecord::FixtureSet
  #def identify(label, column_type = :integer)
  #  ActiveRecord::FixtureSet.identify(label, column_type)
  #end
end
ActiveRecord::FixtureSet.context_class.send :include, FixtureIdHelper
