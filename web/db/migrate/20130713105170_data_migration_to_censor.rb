class DataMigrationToCensor < ActiveRecord::Migration
  def up
    Prof.find(:all).each do |u|
      if u.publish_ok
        u.censor = :none
      else
        u.censor = :everything
      end
      u.save
    end

    Tutor.find(:all).each do |u|
      if u.profs.any? { |p| !p.publish_ok }
        u.censor = :none
      else
        u.censor = :own_comments_and_stats
      end
      u.save
    end
  end

  def down
    warn "Rolling back data migration to :censor is not actually possible."
  end
end
