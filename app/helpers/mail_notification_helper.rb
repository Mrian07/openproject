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

module MailNotificationHelper
  include ::ColorsHelper

  def email_image_tag(image, **options)
    attachments[image] = File.read(Rails.root.join("app/assets/images/#{image}"))
    image_tag attachments[image].url, **options
  end

  def summary_time_frame_text
    # Todo make time configurable for the mentioned mail
    date = Time.parse(Setting.notification_email_digest_time)

    I18n.t(:'mail.notification.time_frame',
           time: Setting.notification_email_digest_time,
           weekday: day_name(date.wday),
           date: ::I18n.l(date.to_date, format: :long))
  end

  def notification_timestamp_text(journal, html: true, extended_text: false)
    user = html ? link_to_user(journal.user, only_path: false) : journal.user.name

    timestamp_text(user, journal, extended_text)
  end


  def unique_reasons_of_notifications(notifications)
    notifications
      .map(&:reason_mail_digest)
      .uniq
  end

  def notifications_path(id)
    notifications_center_url(['details', id, 'activity'])
  end

  def type_color(type, default_fallback)
    color_id = selected_color(type)
    color_id ? Color.find(color_id).hexcode : default_fallback
  end

  def status_colors(status)
    color_id = selected_color(status)
    Color.find(color_id).color_styles.map { |k, v| "#{k}:#{v};" }.join(' ') if color_id
  end

  private

  def timestamp_text(user, journal, extended)
    value = journal.initial? ? "created" : "updated"
    if extended
      raw(I18n.t(:"mail.notifications.work_packages.#{value}") +
            ' ' +
            I18n.t(:"mail.notifications.work_packages.#{value}_at",
                   user: user,
                   timestamp: time_ago_in_words(journal.created_at)))
    else
      raw(I18n.t(:"mail.notifications.work_packages.#{value}_at",
                 user: user,
                 timestamp: time_ago_in_words(journal.created_at)))
    end
  end
end
