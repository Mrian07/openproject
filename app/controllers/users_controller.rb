#-- encoding: UTF-8

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2021 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

class UsersController < ApplicationController
  layout 'admin'

  helper_method :gon

  before_action :authorize_global, except: %i[show deletion_info destroy]

  before_action :find_user, only: %i[show
                                     edit
                                     update
                                     change_status_info
                                     change_status
                                     destroy
                                     deletion_info
                                     resend_invitation]
  # should also contain destroy but post data can not be redirected
  before_action :require_login, only: [:deletion_info]
  before_action :authorize_for_user, only: [:destroy]
  before_action :check_if_deletion_allowed, only: %i[deletion_info
                                                     destroy]

  # Password confirmation helpers and actions
  include PasswordConfirmation
  before_action :check_password_confirmation, only: [:destroy]

  include Accounts::UserLimits
  before_action :enforce_user_limit, only: [:create]
  before_action -> { enforce_user_limit flash_now: true }, only: [:new]

  include SortHelper
  include CustomFieldsHelper
  include PaginationHelper

  def index
    @groups = Group.all.sort
    @status = Users::UserFilterCell.status_param params
    @users = Users::UserFilterCell.filter params

    respond_to do |format|
      format.html do
        render layout: !request.xhr?
      end
    end
  end

  def show
    # show projects based on current user visibility
    @memberships = @user.memberships
                        .where.not(project_id: nil)
                        .visible(current_user)

    events = Activities::Fetcher.new(User.current, author: @user).events(nil, nil, limit: 10)
    @events_by_day = events.group_by { |e| e.event_datetime.to_date }

    if !current_user.allowed_to_globally?(:manage_user) &&
       (!(@user.active? ||
       @user.registered?) ||
       (@user != User.current && @memberships.empty? && events.empty?))
      render_404
    else
      respond_to do |format|
        format.html { render layout: 'no_menu' }
      end
    end
  end

  def new
    @user = User.new(language: Setting.default_language)
  end

  def create
    call = Users::CreateService
           .new(user: current_user)
           .call(create_params)

    @user = call.result

    if call.success?
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to(params[:continue] ? new_user_path : edit_user_path(@user))
    else
      @errors = call.errors
      render action: 'new'
    end
  end

  def edit
    @membership ||= Member.new
    @individual_principal = @user
  end

  def update
    update_params = build_user_update_params
    call = ::Users::UpdateService.new(model: @user, user: current_user).call(update_params)

    if call.success?
      if update_params[:password].present? && @user.change_password_allowed?
        send_information = params[:send_information]

        if @user.activate!
         

          send_information = true
        end

        if @user.active? && send_information
          UserMailer.account_information(@user, update_params[:password]).deliver_later
        end
      end

      respond_to do |format|
        format.html do
          flash[:notice] = I18n.t(:notice_successful_update)
          redirect_back(fallback_location: edit_user_path(@user))
        end
      end
    else
      @membership ||= Member.new
      # Clear password input
      @user = call.result
      @errors = call.errors
      @user.password = @user.password_confirmation = nil

      respond_to do |format|
        format.html do
          render action: :edit
        end
      end
    end
  end

  def change_status_info
    @status_change = params[:change_action].to_sym

    return render_400 unless %i(activate lock unlock).include? @status_change
  end

  def change_status
    if @user.id == current_user.id
      # user is not allowed to change own status
      redirect_back_or_default(action: 'edit', id: @user)
      return
    end

    if (params[:unlock] || params[:activate]) && user_limit_reached?
      show_user_limit_error!

      return redirect_back_or_default(action: 'edit', id: @user)
    end

    if params[:unlock]
      @user.failed_login_count = 0
      @user.activate
    elsif params[:lock]
      @user.lock
    elsif params[:activate]
      @user.activate
    end
    # Was the account activated? (do it before User#save clears the change)
    was_activated = (@user.status_change == %w[registered active])

    if params[:activate] && @user.missing_authentication_method?
      flash[:error] = I18n.t(:error_status_change_failed,
                             errors: I18n.t(:notice_user_missing_authentication_method),
                             scope: :user)
    elsif @user.save
      flash[:notice] = I18n.t(:notice_successful_update)
      if was_activated
        UserMailer.account_activated(@user).deliver_later
      end
    else
      flash[:error] = I18n.t(:error_status_change_failed,
                             errors: @user.errors.full_messages.join(', '),
                             scope: :user)
    end
    redirect_back_or_default(action: 'edit', id: @user)
  end

  def resend_invitation
    status = Principal.statuses[:invited]
    @user.update status: status if @user.status != status

    token = UserInvitation.reinvite_user @user.id

    if token.persisted?
      flash[:notice] = I18n.t(:notice_user_invitation_resent, email: @user.mail)
    else
      logger.error "could not re-invite #{@user.mail}: #{token.errors.full_messages.join(' ')}"
      flash[:error] = I18n.t(:notice_internal_server_error, app_title: Setting.app_title)
    end

    redirect_to edit_user_path(@user)
  end

  def destroy
    # true if the user deletes him/herself
    self_delete = (@user == User.current)

    Users::DeleteService.new(model: @user, user: User.current).call

    flash[:notice] = I18n.t('account.deleted')

    respond_to do |format|
      format.html do
        redirect_to self_delete ? signin_path : users_path
      end
    end
  end

  def deletion_info
    render action: 'deletion_info', layout: my_or_admin_layout
  end

  private

  def find_user
    if params[:id] == 'current' || params['id'].nil?
      require_login || return
      @user = User.current
    else
      @user = User.find(params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def authorize_for_user
    if (User.current != @user ||
        User.current == User.anonymous) &&
       !User.current.admin?

      respond_to do |format|
        format.html { render_403 }
        format.xml  { head :unauthorized, 'WWW-Authenticate' => 'Basic realm="OpenProject API"' }
        format.js   { head :unauthorized, 'WWW-Authenticate' => 'Basic realm="OpenProject API"' }
        format.json { head :unauthorized, 'WWW-Authenticate' => 'Basic realm="OpenProject API"' }
      end

      false
    end
  end

  def check_if_deletion_allowed
    render_404 unless Users::DeleteContract.deletion_allowed? @user, User.current
  end

  def my_or_admin_layout
    # TODO: how can this be done better:
    # check if the route used to call the action is in the 'my' namespace
    if url_for(:delete_my_account_info) == request.url
      'my'
    else
      'admin'
    end
  end

  def set_password?(params)
    params[:user][:password].present? && !OpenProject::Configuration.disable_password_choice?
  end

  protected

  def default_breadcrumb
    if action_name == 'index'
      t('label_user_plural')
    else
      ActionController::Base.helpers.link_to(t('label_user_plural'), users_path)
    end
  end

  def show_local_breadcrumb
    action_name != 'show'
  end

  def build_user_update_params
    pref_params = permitted_params.pref.to_h
    update_params = permitted_params
      .user_create_as_admin(@user.uses_external_authentication?, @user.change_password_allowed?)
      .to_h
      .merge(pref: pref_params)

    return update_params unless @user.change_password_allowed?

    if params[:user][:assign_random_password]
      password = OpenProject::Passwords::Generator.random_password
      update_params.merge!(
        password: password,
        password_confirmation: password,
        force_password_change: true
      )
    elsif set_password? params
      update_params.merge!(
        password: params[:user][:password],
        password_confirmation: params[:user][:password_confirmation]
      )
    end

    update_params
  end

  def create_params
    permitted_params
      .user_create_as_admin(false, false)
      .merge(admin: params[:user][:admin] || false,
             login: params[:user][:login] || params[:user][:mail],
             status: User.statuses[:invited])
  end
end
