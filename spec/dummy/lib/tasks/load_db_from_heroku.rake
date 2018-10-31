namespace :db do
  namespace :heroku do
    desc 'capture DB Backup'
    task capture_backup: :environment do
      if Rails.env == 'development'
        Bundler.with_clean_env do
          system 'heroku pg:backups capture -a sweetstaging'
        end
      end
    end

    desc 'Pull DB Backup'
    task download_backup: :capture_backup do
      if Rails.env == 'development'
        Bundler.with_clean_env do
          system 'curl -o latest.dump `heroku pg:backups public-url -a sweetstaging`'
        end
      end
    end

    desc 'Load the PROD database from Heroku to the local dev database'
    task load: :download_backup do
      if Rails.env == 'development'
        Bundler.with_clean_env do
          config = Rails.configuration.database_configuration[Rails.env]
          if config['username']
            system <<-CMD
              pg_restore --verbose --clean --no-acl --no-owner -h localhost \
                -U #{config['username']} -d #{config['database']} latest.dump
              rm -rf latest.dump
            CMD
          else
            system <<-CMD
              pg_restore --verbose --clean --no-acl --no-owner -h localhost \
              -d #{config['database']} latest.dump
              rm -rf latest.dump
            CMD
          end
        end
      end
    end
  end
end
