module UserResource
  private

  def load_user
    @user = User.find_by_login(params[:user_id])
  end

  def current_user_must_be_user_resource
    raise SecurityTransgression unless @user == current_user
  end
end