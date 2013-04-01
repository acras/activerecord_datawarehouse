#coding: utf-8

class DatawarehouseTasks < Rails::Railtie
  rake_tasks do
    Dir[File.join(File.dirname(__FILE__),'../tasks/*.rake')].each { |f| load f }
  end
end