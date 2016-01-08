require 'ansi'
#require 'oj'

require 'rails/version'
require 'active_record'
require 'active_model'

require 'elasticsearch/model'
require 'elasticsearch/rails'
require 'elasticsearch/rails/ha'

require 'temp_db_helper'
require 'es_helper'

RSpec.configure do |config|
  #config.profile_examples = 10

  config.order = :random

  Kernel.srand config.seed

  config.before(:suite) do
    ESHelper.setup
    ESHelper.startup
  end

  config.after(:suite) do
    ESHelper.shutdown
  end
end
