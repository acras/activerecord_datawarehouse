namespace :datawarehouse do
  namespace :db do
    desc "Migrate datawarehouse database"
    task(:migrate => :environment) do
      ActiveRecord::Base.establish_connection("dw_#{Rails.env}")
      ActiveRecord::Migrator.migrate("db/migrate/dw_migrations/")
    end

    namespace :migrate do
      desc "Migrate specific migration on datawarehouse database"
      task(:up => :environment) do
        ActiveRecord::Migrator.up("db/migrate/dw_migrations/")
      end

      desc "Rollback migration on datawarehouse database"
      task(:down => :environment) do
        ActiveRecord::Migrator.down("db/migrate/dw_migrations/")
      end
    end
  end
end
