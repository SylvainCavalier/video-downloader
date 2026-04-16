class DownloadPolicy < ApplicationPolicy
  def file?
    owned? && record.completed?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user_id: user.id)
    end
  end
end
