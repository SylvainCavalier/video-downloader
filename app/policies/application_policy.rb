class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?   = user.present?
  def show?    = owned?
  def create?  = user.present?
  def new?     = create?
  def update?  = owned?
  def edit?    = update?
  def destroy? = owned?

  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "You must define #resolve in #{self.class}"
    end
  end

  private

  def owned?
    record.respond_to?(:user_id) && record.user_id == user&.id
  end
end
