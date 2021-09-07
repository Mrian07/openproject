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

module OpenProject
  module Enterprise
    class << self
      def token
        EnterpriseToken.current.presence
      end

      def upgrade_url
        "#{Setting.protocol}://#{Setting.host_name}#{upgrade_path}"
      end

      def upgrade_path
        url_helpers.enterprise_path
      end

      

      ##
      # Indicates if there are more active users than the support token allows for.
      #
      # @return [Boolean] True if and only if there is a support token the user limit of which is exceeded.
      

      ##
      # Informs active admins about a user who could not be activated due to
      # the user limit having been reached.
      def send_activation_limit_notification_about(user)
        User.active.admin.each do |admin|
          UserMailer.activation_limit_reached(user.mail, admin).deliver_later
        end
      end

      private

      def url_helpers
        @url_helpers ||= OpenProject::StaticRouting::StaticUrlHelpers.new
      end
    end
  end
end
