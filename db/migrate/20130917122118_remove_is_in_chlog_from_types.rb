#-- copyright
# OpenProject is a project management system.
#
# Copyright (C) 2012-2013 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

class RemoveIsInChlogFromTypes < ActiveRecord::Migration
  def up
    remove_column :types, :is_in_chlog
  end

  def down
    add_column :types, :is_in_chlog, :boolean, :default => false, :null => false
  end
end
