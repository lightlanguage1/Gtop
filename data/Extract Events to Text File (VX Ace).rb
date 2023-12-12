#============================================================================
# EXTRACT EVENTS
# v1.03 by Shaz
#----------------------------------------------------------------------------
# This script extracts ALL event commands into a number of text files.
# These can be opened in a spreadsheet, split into columns, searched and
# sorted.
# 
# Data/_EventContents.txt
# Contains ALL event commands
# - useful for perusing, searching for anything in any event
# - this also includes everything in the following two files
#
# Data/_EventDialogue.txt
# A subset of _EventContents.txt
# Contains any event commands to do with text - Show Text, Show Choices, 
# actor names, etc
# - useful for proofreading and translation (there is no facility to replace
#   text with translations - this is JUST an extract)
#
# Data/_EventSwitchesVariables.txt
# A subset of _EventContents.txt
# Contains any event commands and conditions to do with switches and variables
# - useful for finding where they've been used
#----------------------------------------------------------------------------
# To Install:
# Copy and paste into a new slot in materials, below all other scripts
#----------------------------------------------------------------------------
# To Customize:
# Change the values of the following constants and variables
#
#  EXPORT_COMMON_EVENTS = true
#    true to export common events
#    false to exclude common events
#
#  EXPORT_BATTLE_EVENTS = true
#    true to export battle events
#    false to export battle events
#
#  MAP_START = 1
#  MAP_END = 999
#    range of maps to include
#    set to 1 and 999 for all maps
#    change both to the same map number to export just a single map
#
#  EXPAND_MOVE_ROUTES = true
#    true to export every line in a move route command
#    false to export the move route "heading" only, but no individual move route commands
#
#  INDENT = true
#  @ind = ". "
#    true to indent text within blocks, as you see it in the editor
#    false to align everything to the left
#    if true, @ind is the string that will be repeated to show indenting
#
#  @cb = "^"
#    column break character - this MUST be something that is not used
#    in any text or Call Script commands
#
#  @lb = "\n"
#    line break character - changing this is not recommended
#
#----------------------------------------------------------------------------
# To Use:
# You do not "call" this script.  
# Paste it, hit Play Test.
# When your title screen appears, the script has run and the files have been
# created.
# 
# The script will run every time you play unless you disable it.  
# Once you've run it once, edit the script and disable the whole thing
# (Ctrl A to select all, Ctrl Q to disable)
# Enable it when you want to run it again (same key sequence)
#
# Once the files have been created, open them in a spreadsheet and use the
# Text to Columns feature to separate based on your chosen delimiter
#----------------------------------------------------------------------------
# Terms:
# This is a DEVELOPMENT ONLY script.  You may use it when creating free or
# commercial games, but PLEASE remove the script before the game is released.
# You do NOT need to credit me in the game.
# If you share this script, PLEASE keep this header intact, and include a
# link back to the original RPG Maker Web forum post.
#----------------------------------------------------------------------------
# Revisions:
# 1.01  Jun 22 2014   Fix troop condition crash
# 1.02  May 11 2020   Fix crash on Change Parallax
# 1.03  Jul 22 2020   Fix name on Show Balloon Icon
#                     Fix actor in Change Equipment
#                     Fix actor in Change Nickname
#============================================================================


class Game_Event < Game_Character
  attr_reader    :event
  attr_reader    :name
  attr_reader    :pages
  
  alias shaz_ee_game_event_initialize initialize
  def initialize(map_id, event)
    @name = event.name
    @pages = event.pages
    shaz_ee_game_event_initialize(map_id, event)
  end
end

module EVExport
  EXPORT_COMMON_EVENTS = true
  EXPORT_BATTLE_EVENTS = true
  MAP_START = 1
  MAP_END = 999
  EXPAND_MOVE_ROUTES = true
  INDENT = true
  
  @cb = "^"
  @lb = "\n"
  @ind = ". "
  
  @expline = 0
  
  def self.export
    DataManager.load_normal_database
    DataManager.create_game_objects
    @file_all = File.open('Data/_EventContents.txt', 'w')
    @file_text = File.open('Data/_EventDialogue.txt', 'w')
    @file_swvar = File.open('Data/_EventSwitchesVariables.txt', 'w')
    
    text = sprintf("%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s",
      'Seq', @cb, 'Type', @cb, 'Source', @cb, 'Event ID', @cb, 'Name', @cb,
      'Page', @cb, 'Line', @cb, 'Code', @cb, 'Command', @cb, 'Arguments', @lb)
      
    @file_all.print(text)
    @file_text.print(text)
    
    text = sprintf("%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s%s",
      'Seq', @cb, 'Type', @cb, 'Source', @cb, 'Event ID', @cb, 'Name', @cb,
      'Page', @cb, 'Line', @cb, 'Code', @cb, 'Command', @cb, 'Switch/Var', @cb,
      'Arguments', @lb)
    
    @file_swvar.print(text)
    
    @mapnames = []
    for m in 1...999
      if File.exists?(sprintf('Data/Map%03d.rvdata2', m))
        @mapnames[m] = load_data(sprintf("Data/Map%03d.rvdata2", m)).display_name
      else
        @mapnames[m] = 'undefined'
      end
    end
    
    @sv3 = nil
    self.export_common_events if EXPORT_COMMON_EVENTS
    self.export_battle_events if EXPORT_BATTLE_EVENTS
    @event_seq = 3
    for m in MAP_START .. MAP_END
      self.export_map_events(m) if File.exists?(sprintf('Data/Map%03d.rvdata2', m))
    end
    
    @file_all.close
    @file_text.close
  end
  
  def self.export_common_events
    @event_seq = 1
    @event_type = "Common Event"
    @event_tab = ""
    for @event in $data_common_events.compact
      @event_source = sprintf("%d%s%s", @event.id, @cb, @event.name)
      @list = @event.list
      self.export_common_event_conditions
      self.export_event_list
    end
  end
  
  def self.export_battle_events
    @event_seq = 2
    for troop in $data_troops
      next if troop.nil?
      @event_type = "Troop"
      @event_source = sprintf("%d%s%s", troop.id, @cb, troop.name)
      for index in 0..troop.pages.size - 1
        @event_tab = index.to_s
        page = troop.pages[index]
        @cond = page.condition
        @list = page.list
        self.export_troop_event_conditions
        self.export_event_list
      end
    end
  end
  
  def self.export_map_events(m)
    $game_map.setup(m)
    @event_type = sprintf("Map %3d (%s - %s)", m, $game_map.display_name, @mapnames[m])
    
    for event_key in $game_map.events.keys
      @event = $game_map.events[event_key]
      next if @event.nil? || @event.pages.nil?
      @event_source = sprintf("%d%sEV%03d (%d,%d) - %s", @event.id, @cb, @event.id, 
      @event.event.x, @event.event.y, @event.name)
      for page in 0..@event.pages.size - 1
        @event_tab = (page + 1).to_s
        @cond = @event.pages[page].condition
        @list = @event.pages[page].list
        self.export_map_event_conditions
        self.export_event_list
      end
    end
  end
  
  def self.export_common_event_conditions
    @line = 0
    @sv2 = nil
    if @event.trigger != 0
      @swvar_export = true
      @sv1 = get_switch(@event.switch_id)
      @cmd = "Switch"
      @arg = sprintf('%s is ON', @sv1)
      self.export_condition
    end
  end
  
  def self.export_troop_event_conditions
    @line = 0
    @sv1 = nil
    @sv2 = nil
    if @cond.turn_ending
      @cmd = 'Turn'
      @arg = 'End of turn'
      @swvar_export = false
      self.export_condition
    end
    if @cond.turn_valid
      @cmd = 'Turn'
      @arg = sprintf('Turn no. %d + %d * X', @cond.turn_a, @cond.turn_b)
      @swvar_export = false
      self.export_condition
    end
    if @cond.enemy_valid
      @cmd = 'Enemy'
      @arg = sprintf('Enemy %d\'s HP is %d%% or below', @cond.enemy_index,
        @cond.enemy_hp)
      @swvar_export = false
      self.export_condition
    end
    if @cond.actor_valid
      @cmd = 'Actor'
      @arg = sprintf('Actor %d\'s HP is %d%% or below', @cond.actor_id,
        @cond.actor_hp)
      @swvar_export = false
      self.export_condition
    end
    if @cond.switch_valid
      @sv1 = get_switch(@cond.switch_id)
      @cmd = 'Switch'
      @arg = sprintf('%s is ON', @sv1)
      @swvar_export = true
      self.export_condition
    end
  end
  
  def self.export_map_event_conditions
    @line = 0
    @sv2 = nil
    @swvar_export = true
    if @cond.switch1_valid
      @sv1 = get_switch(@cond.switch1_id)
      @cmd = 'Switch'
      @arg = sprintf('%s is ON', @sv1)
      self.export_condition
    end
    if @cond.switch2_valid
      @sv1 = get_switch(@cond.switch2_id)
      @cmd = 'Switch'
      @arg = sprintf('%s is ON', @sv1)
      self.export_condition
    end
    @sv1 = nil
    if @cond.variable_valid
      @sv1 = get_variable(@cond.variable_id)
      @cmd = 'Variable'
      @arg = sprintf('%s >= %d', @sv1, @cond.variable_value)
      self.export_condition
    end
    @swvar_export = false
    if @cond.self_switch_valid
      @cmd = 'Self Switch'
      @arg = sprintf('Self Switch %s is ON', @cond.self_switch_ch)
      self.export_condition
    end
    if @cond.item_valid
      @cmd = 'Item'
      @arg = sprintf('Item %d (%s) is in Inventory', @cond.item_id,
        self.item_name(@cond.item_id))
      self.export_condition
    end
    if @cond.actor_valid
      @cmd = 'Actor'
      @arg = sprintf('Actor %d (%s) is in the Party', @cond.actor_id,
        self.actor_name(@cond.actor_id))
      self.export_condition
    end
  end
  
  def self.export_event_list
    return if @list.nil?
    @cmdline = 0
    
    while @cmdline < @list.size
      @line = @cmdline + 1
      @command = @list[@cmdline]
      @params = @command.parameters.clone
      @indent = @command.indent
      @cmd = ""
      @arg = ""
      @sv1 = nil
      @sv2 = nil
      @sv3 = nil
      @skip_export = false
      @text_export = false
      @swvar_export = false
      method_name = "command_#{@command.code}"
      send(method_name) if respond_to?(method_name)
      self.export_command if !@skip_export
      @cmdline += 1
    end
  end
  
  def self.get_switch(id)
    sprintf('Switch %04d [%s]', id, $data_system.switches[id])
  end
  
  def self.get_variable(id)
    sprintf('Variable %04d [%s]', id, $data_system.variables[id])
  end
  
  def self.actor_name(id)
    $data_actors[id].nil? ? 'undefined' : $data_actors[id].name
  end
  
  def self.class_name(id)
    $data_classes[id].nil? ? 'undefined' : $data_classes[id].name
  end
  
  def self.skill_name(id)
    $data_skills[id].nil? ? 'undefined' : $data_skills[id].name
  end
  
  def self.item_name(id)
    $data_items[id].nil? ? 'undefined' : $data_items[id].name
  end
  
  def self.weapon_name(id)
    $data_weapons[id].nil? ? 'undefined' : $data_weapons[id].name
  end
  
  def self.armor_name(id)
    $data_armors[id].nil? ? 'undefined' : $data_armors[id].name
  end
  
  def self.enemy_name(id)
    $data_enemies[id].nil? ? 'undefined' : $data_enemies[id].name
  end
  
  def self.troop_name(id)
    $data_troops[id].nil? ? 'undefined' : $data_troops[id].name
  end
  
  def self.state_name(id)
    $data_states[id].nil? ? 'undefined' : $data_states[id].name
  end
  
  def self.animation_name(id)
    $data_animations[id].nil? ? 'undefined' : $data_animations[id].name
  end
  
  def self.tileset_name(id)
    $data_tilesets[id].nil? ? 'undefined' : $data_tilesets[id].name
  end
  
  def self.common_event_name(id)
    $data_common_events[id].nil? ? 'undefined' : $data_common_events[id].name
  end
    
  def self.next_event_code
    @list[@cmdline + 1].code
  end
  
  def self.get_operator(operator)
    return ['=', '+=', '-=', '*=', '/=', '%='][operator]
  end
    
  def self.operate_value(sign, value, const = true)
    @swvar_export = !const
    @sv1 = get_variable(value) if @swvar_export
    return sprintf("%s %s", (sign == 0 ? "+" : "-"),
      (const ? value.to_s : sprintf("%s", @sv1)))
  end
  
  def self.get_actor(type, id)
    @swvar_export = type != 0
    @sv1 = get_variable(id) if @swvar_export
    return type == 0 ? (id == 0 ? "All actors" : sprintf('Actor %d (%s)', id,
      self.actor_name(id))) : sprintf('Actor %s', @sv1)
  end
  
  def self.get_enemy(id)
    return id < 0 ? "All enemies" : ("Enemy " + id.to_s)
  end
    
  def self.get_character(character)
    return character < 0 ? "Player" : character > 0 ? ("Event " + character.to_s) :
      "This event"
  end
    
  def self.get_direction(dir)
    return ['', '', 'down', '', 'left', '', 'right', '', 'up'][dir]
  end
  
  def self.get_audio(audio)
    return sprintf("%s;  Volume %d  Pitch %d", audio.name, audio.volume, audio.pitch)
  end
  
  def self.get_vehicle(vehicle)
    return ['boat', 'ship', 'airship'][vehicle]
  end
 
  def self.get_map_loc(map, x, y, const = true)
    @swvar_export = !const
    if const
      return sprintf("%d (%s - %s), (%d, %d)", map, @mapnames[map],
        $data_mapinfos[map] ? $data_mapinfos[map].name : 'unknown', x, y)
    else
      @sv1 = get_variable(map)
      @sv2 = get_variable(x)
      @sv3 = get_variable(y)
      return sprintf("%s, (%s, %s)", @sv1, @sv2, @sv3)
    end
  end
 
  def self.get_loc(x, y, const = true)
    if const
      return sprintf("(%d, %d)", x, y)
    else
      @swvar_export = true
      @sv1 = get_variable(x)
      @sv2 = get_variable(y)
      return sprintf("(%s, %s)", @sv1, @sv2)
    end
  end
  
  def self.command_0
    @skip_export = true
  end
  def self.command_505
    @skip_export = true
  end
  def self.command_404
    @cmd = "End Show Choices"
    @arg = 'end choices'
  end
  def self.command_412
    @cmd = "End Conditional Branch"
    @arg = 'end condition'
  end
  def self.command_604
    @cmd = "End Battle Result"
    @arg = 'end battle result'
  end

  #--------------------------------------------------------------------------
  # * Show Text
  #--------------------------------------------------------------------------
  def self.command_101
    @text_export = true
    @cmd = "Show Text"
    @arg = sprintf('Face: %s (index %d) on %s at %s', 
      (@params[0] == "" ? 'none' : @params[0]), @params[1],
      ['normal window', 'dim background', 'transparent'][@params[2]],
      ['top', 'middle', 'bottom'][@params[3]])
  end
  def self.command_401
    @text_export = true
    @cmd = "Show Text"
    @arg = @params[0]
  end
  #--------------------------------------------------------------------------
  # * Show Choices
  #--------------------------------------------------------------------------
  def self.command_102
    @text_export = true
    @cmd = "Show Choices"
    for choice in @params[0]
      @arg += choice + "; "
    end
  end
  #--------------------------------------------------------------------------
  # * When [**]
  #--------------------------------------------------------------------------
  def self.command_402
    @text_export = true
    @cmd = "When [**]"
    @arg = "When " + @params[1]
  end
  #--------------------------------------------------------------------------
  # * When Cancel
  #--------------------------------------------------------------------------
  def self.command_403
    @text_export = true
    @cmd = "When Cancel"
    @arg = "When Cancel"
  end
  #--------------------------------------------------------------------------
  # * Input Number
  #--------------------------------------------------------------------------
  def self.command_103
    @cmd = "Input Number"
    @sv1 = get_variable(@params[0])
    @arg = sprintf("%s  Digits: %d", @sv1, @params[1])
    @swvar_export = true
  end
  #--------------------------------------------------------------------------
  # * Select Item
  #--------------------------------------------------------------------------
  def self.command_104
    @cmd = "Select Item"
    @sv1 = @params[0]
    @args = sprintf("%s", @sv1)
    @swvar_export = true
  end
  #--------------------------------------------------------------------------
  # * Show Scrolling Text
  #--------------------------------------------------------------------------
  def self.command_105
    @text_export = true
    @cmd = "Show Scrolling Text"
    while next_event_code == 405
      @cmdline += 1
      @arg += @list[@cmdline].parameters[0] + " "
    end
  end
  #--------------------------------------------------------------------------
  # * Comment
  #--------------------------------------------------------------------------
  def self.command_108
    @cmd = "Comment"
    @arg = @params[0]
  end
  def self.command_408
    @cmd = "Comment"
    @arg = @params[0]
  end
  #--------------------------------------------------------------------------
  # * Conditional Branch
  #--------------------------------------------------------------------------
  def self.command_111
    @cmd = "Conditional Branch"
    @arg = "IF "
    case @params[0]
    when 0 # Switch
      @swvar_export = true
      @sv1 = get_switch(@params[1])
      @arg += sprintf("%s is %s", @sv1, (@params[2] == 0 ? "ON" : "OFF"))
    when 1 # Variable
      @swvar_export = true
      @sv1 = get_variable(@params[1])
      @arg += sprintf("%s %s ", @sv1, ['==', '>=', '<=', '>', '<', '!='][@params[4]])
      if @params[2] == 0 #constant
        @arg += @params[3].to_s
      else
        @sv2 = get_variable(@params[3])
        @arg += sprintf("%s", @sv2)
      end
    when 2 # Self Switch
      @arg += sprintf("Self Switch %s is %s", @params[1],
        (@params[2] == 0 ? "ON" : "OFF"))
    when 3 # Timer
      @arg += sprintf("Timer: %d minutes %d seconds or %s", @params[1]/60,
        @params[1]%60, (@params2 == 0 ? "more" : "less"))
    when 4 # Actor
      @arg += sprintf("Actor %d (%s): ", @params[1], self.actor_name(@params[1]))
      case @params[2]
      when 0
        @arg += "is in the party"
      when 1
        @text_export = true
        @arg += sprintf("name is %s", @params[3])
      when 2
        @arg += sprintf("is class %d (%s)", @params[3], self.class_name(@params[3]))
      when 3
        @arg += sprintf("knows skill %d (%s)", @params[3], self.skill_name(@params[3]))
      when 4
        @arg += sprintf("has weapon %d (%s) equipped", @params[3], self.weapon_name(@params[3]))
      when 5
        @arg += sprintf("has armor %d (%s) equipped", @params[3], self.armor_name(@params[3]))
      when 6
        @arg += sprintf("has state %d (%s) applied", @params[3], self.state_name(@params[3]))
      end
    when 5 # Enemy
      @arg += sprintf("Enemy %d ", @params[1])
      case @params[2]
      when 0 # appear
        @arg += "is visible"
      when 1 # state
        @arg += sprintf("has state %d (%s) applied", @params[3], self.state_name(@params[3]))
      end
    when 6 # Character facing
      @arg += sprintf("%s is facing %s", self.get_character(@params[1]),
        self.get_direction(@params[2]))
    when 7 # Gold
      @arg += sprintf("Gold %s %d", (@params[2] == 0 ? ">=" : @params[2] == 1 ? "<=" : "<"),
        @params[1])
    when 8 # Item
      @arg += sprintf("Party has item %d (%s)", @params[1], self.item_name(@params[1]))
    when 9 # Weapon
      @arg += sprintf("Party has weapon %d (%s)", @params[1],
        self.weapon_name(@params[1]))
      @arg += ' (including equipped)' if @params[2]
    when 10 # Armor
      @arg += sprintf("Party has armor %d (%s)", @params[1],
        self.armor_name(@params[1]))
      @arg += ' (including equipped)' if @params[2]
    when 11 # Button
      @arg += sprintf("Button %s is pressed", ['0', '1', 'down', '3', 'left', '5', 'right',
        '7', 'up', '9', '10', 'A', 'B', 'C', 'X', 'Y', 'Z', 'L', 'R'][@params[1]])
    when 12 # Script
      @arg += sprintf("Script (%s)", @params[1])
    when 13 # Vehicle
      @arg += sprintf("Player is in %s", self.get_vehicle(@params[1]))
    end
  end
  #--------------------------------------------------------------------------
  # * Else
  #--------------------------------------------------------------------------
  def self.command_411
    @cmd = "Else"
    @arg = "Else"
  end
  #--------------------------------------------------------------------------
  # * Loop
  #--------------------------------------------------------------------------
  def self.command_112
    @cmd = "Loop"
    @arg = "Loop"
  end
  #--------------------------------------------------------------------------
  # * Repeat Above
  #--------------------------------------------------------------------------
  def self.command_413
    @cmd = "Repeat Above"
    @arg = "Repeat Above"
  end
  #--------------------------------------------------------------------------
  # * Break Loop
  #--------------------------------------------------------------------------
  def self.command_113
    @cmd = "Break Loop"
    @arg = "Break Loop"
  end
  #--------------------------------------------------------------------------
  # * Exit Event Processing
  #--------------------------------------------------------------------------
  def self.command_115
    @cmd = "Exit Event Processing"
    @arg = "Exit Event Processing"
  end
  #--------------------------------------------------------------------------
  # * Common Event
  #--------------------------------------------------------------------------
  def self.command_117
    @cmd = "Common Event"
    @arg = sprintf("Common Event %03d (%s)", @params[0],
      self.common_event_name(@params[0]))
  end
  #--------------------------------------------------------------------------
  # * Label
  #--------------------------------------------------------------------------
  def self.command_118
    @cmd = "Label"
    @arg = @params[0]
  end
  #--------------------------------------------------------------------------
  # * Jump to Label
  #--------------------------------------------------------------------------
  def self.command_119
    @cmd = "Jump to Label"
    @arg = @params[0]
  end
  #--------------------------------------------------------------------------
  # * Control Switches
  #--------------------------------------------------------------------------
  def self.command_121
    @cmd = "Control Switches"
    @swvar_export = true
    for s in @params[0]..@params[1]
      @sv1 = get_switch(s)
      @arg = sprintf("%s = %s", @sv1, (@params[2] == 0 ? "ON" : "OFF"))
      self.export_command
    end
    @skip_export = true  
  end
  #--------------------------------------------------------------------------
  # * Control Variables
  #--------------------------------------------------------------------------
  def self.command_122
    @cmd = "Control Variables"
    @swvar_export = true
    case @params[3]
    when 0 # Constant
      value = @params[4].to_s
    when 1 # Variable
      @sv2 = get_variable(@params[4])
      value = sprintf("%s", @sv2)
    when 2 # Random
      value = sprintf("Random %d - %d", @params[4], @params[5])
    when 3 # Game Data
      case @params[4]
      when 0 # Items
        value = sprintf("Item %d (%s) in inventory", @params[5], self.item_name(@params[5]))
      when 1 # Weapons
        value = sprintf("Weapon %d (%s) in inventory", @params[5], self.item_name(@params[5]))
      when 2 # Armor
        value = sprintf("Armor %d (%s) in inventory", @params[5], self.item_name(@params[5]))
      when 3 # Actor
        value = sprintf("Actor %d's (%s) %s", @params[5], self.actor_name(@params[5]),
          ['level', 'EXP', 'HP', 'MP', 'MHP', 'MMP', 'ATK', 'DEF', 'MAT', 'MDF', 
          'AGI', 'LUK'][@params[6]])
      when 4 # Enemy
        value = sprintf("Enemy %d's %s", @params[5], 
          ['HP', 'MP', 'MHP', 'MMP', 'ATK', 'DEF', 'MAT', 'MDF', 
          'AGI', 'LUK'][@params[6]])
      when 5 # Character
        value = sprintf("%s's %s", self.get_character(@params[5]),
          ['x coordinate', 'y coordinate', 'direction', 'screen x coordinate', 
          'screen y coordinate'][@params[6]])
      when 6 # Party
        value = sprintf("Party member %d's id", @params[5])
      when 7 # Other
        value = ['Map ID', 'Party Size', 'Gold', 'Steps', 'Play Time', 'Timer',
          'Save Count', 'Battle Count'][@params[5]]
      end
    when 4 # Script
      value = sprintf("Script: %s", @params[4])
    end
    
    operator = get_operator(@params[2])

    (@params[0]..@params[1]).each do |i|
      @sv1 = get_variable(i)
      @arg = sprintf("%s %s %s", @sv1, operator, value)
      self.export_command
    end
    @skip_export = true
  end
  #--------------------------------------------------------------------------
  # * Control Self Switch
  #--------------------------------------------------------------------------
  def self.command_123
    @cmd = "Control Self Switch"
    @arg = sprintf("Self Switch %s = %s", @params[0], (@params[1] ? "true" : "false"))
  end
  #--------------------------------------------------------------------------
  # * Control Timer
  #--------------------------------------------------------------------------
  def self.command_124
    @cmd = "Control Timer"
    if @params[0] == 0
      @arg = sprintf("Start Timer at %d minutes, %d seconds", @params[1]/60, @params[1]%60)
    else
      @arg = "Stop Timer"
    end
  end
  #--------------------------------------------------------------------------
  # * Change Gold
  #--------------------------------------------------------------------------
  def self.command_125
    @cmd = "Change Gold"
    @arg = sprintf("%s", self.operate_value(@params[0], @params[2], @params[1] == 0))
  end
  #--------------------------------------------------------------------------
  # * Change Items
  #--------------------------------------------------------------------------
  def self.command_126
    @cmd = "Change Items"
    @arg = sprintf("Item %d (%s) %s", @params[0], self.item_name(@params[0]),
      self.operate_value(@params[1], @params[3], @params[2] == 0))
  end
  #--------------------------------------------------------------------------
  # * Change Weapons
  #--------------------------------------------------------------------------
  def self.command_127
    @cmd = "Change Weapons"
    @arg = sprintf("Weapon %d (%s) %s", @params[0], self.weapon_name(@params[0]),
      self.operate_value(@params[1], @params[3], @params[2] == 0))
    @arg += " (include equipped)" if @params[1] == 0 && @params[4]
  end
  #--------------------------------------------------------------------------
  # * Change Armor
  #--------------------------------------------------------------------------
  def self.command_128
    @cmd = "Change Armor"
    @arg = sprintf("Armor %d (%s) %s", @params[0], self.armor_name(@params[0]),
      self.operate_value(@params[1], @params[3], @params[2] == 0))
    @arg += " (include equipped)" if @params[1] == 0 && @params[4]
  end
  #--------------------------------------------------------------------------
  # * Change Party Member
  #--------------------------------------------------------------------------
  def self.command_129
    @cmd = "Change Party Member"
    @arg = sprintf("%s %s %s", (@params[1] == 0 ? "+" : "-"), self.get_actor(0, @params[0]),
      (@params[1] == 0 && @params[2] == 1 ? "(initialize)" : ""))
  end
  #--------------------------------------------------------------------------
  # * Change Battle BGM
  #--------------------------------------------------------------------------
  def self.command_132
    @cmd = "Change Battle BGM"
    @arg = sprintf("BGM %s", self.get_audio(@params[0]))
  end
  #--------------------------------------------------------------------------
  # * Change Battle End ME
  #--------------------------------------------------------------------------
  def self.command_133
    @cmd = "Change Battle End ME"
    @arg = sprintf("ME %s", self.get_audio(@params[0]))
  end
  #--------------------------------------------------------------------------
  # * Change Save Access
  #--------------------------------------------------------------------------
  def self.command_134
    @cmd = "Change Save Access"
    @arg = @params[0] == 0 ? "disable" : "enable"
  end
  #--------------------------------------------------------------------------
  # * Change Menu Access
  #--------------------------------------------------------------------------
  def self.command_135
    @cmd = "Change Menu Access"
    @arg = @params[0] == 0 ? "disable" : "enable"
  end
  #--------------------------------------------------------------------------
  # * Change Encounter Disable
  #--------------------------------------------------------------------------
  def self.command_136
    @cmd = "Change Encounter Disable"
    @arg = @params[0] == 0 ? "disable" : "enable"
  end
  #--------------------------------------------------------------------------
  # * Change Formation Access
  #--------------------------------------------------------------------------
  def self.command_137
    @cmd = "Change Formation Access"
    @arg = @params[0] == 0 ? "disable" : "enable"
  end
  #--------------------------------------------------------------------------
  # * Change Window Color
  #--------------------------------------------------------------------------
  def self.command_138
    @cmd = "Change Window Color"
    @arg = @params[0].to_s
  end
  #--------------------------------------------------------------------------
  # * Transfer Player
  #--------------------------------------------------------------------------
  def self.command_201
    @cmd = "Transfer Player"
    @arg = sprintf("Map %s", self.get_map_loc(@params[1], @params[2], @params[3],
      @params[0] == 0))
    @arg += ' Direction: ' + self.get_direction(@params[4])
  end
  #--------------------------------------------------------------------------
  # * Set Vehicle Location
  #--------------------------------------------------------------------------
  def self.command_202
    @cmd = "Set Vehicle Location"
    @arg = sprintf("%s to Map %s", self.get_vehicle(@params[0]),
      self.get_map_loc(@params[2], @params[3], @params[4], @params[1] == 0))
  end
  #--------------------------------------------------------------------------
  # * Set Event Location
  #--------------------------------------------------------------------------
  def self.command_203
    @cmd = "Set Event Location"
    if [0,1].include?(@params[1])
      @arg = sprintf("%s to %s", self.get_character(@params[0]), self.get_loc(@params[2],
        @params[3], @params[1] == 0))
    else
      @arg = sprintf("swap %s and %s", self.get_character(@params[0]),
        self.get_character(@params[2]))
    end
    @arg += ' direction ' + self.get_direction(@params[4]) if @params[4] > 0
  end
  #--------------------------------------------------------------------------
  # * Scroll Map
  #--------------------------------------------------------------------------
  def self.command_204
    @cmd = "Scroll Map"
    @arg = sprintf('%s %d tiles, speed %d', 
      self.get_direction(@params[0]), @params[1],
      @params[2])
  end
  #--------------------------------------------------------------------------
  # * Set Move Route
  #--------------------------------------------------------------------------
  def self.command_205
    @cmd = "Set Move Route"
    @arg = self.get_character(@params[0])
    mvr = @params[1]
    extra = ''
    extra = ' (repeat' if mvr.repeat
    extra += (mvr.repeat ? ', ' : ' (') + 'skip if can\'t move' if mvr.skippable
    extra += (mvr.repeat || mvr.skippable ? ', ' : ' (') + 'wait' if mvr.wait
    extra += ')' if extra != ''
    @arg += extra
    self.export_command
    
    if EXPAND_MOVE_ROUTES
      mvr.list.each do |cmd|
        mp = cmd.parameters
        @arg = '  '
        @sv1 = nil
        @swvar_export = false
        case cmd.code
        when 0
          @arg += 'end'
        when 1
          @arg += 'move down'
        when 2
          @arg += 'move left'
        when 3
          @arg += 'move right'
        when 4
          @arg += 'move up'
        when 5
          @arg += 'move lower left'
        when 6
          @arg += 'move lower right'
        when 7
          @arg += 'move upper left'
        when 8
          @arg += 'move upper right'
        when 9
          @arg += 'move at random'
        when 10
          @arg += 'move toward player'
        when 11
          @arg += 'move away from player'
        when 12
          @arg += '1 step forward'
        when 13
          @arg += '1 step backward'
        when 14
          @arg += sprintf('jump %d, %d', mp[0], mp[1])
        when 15
          @arg += sprintf('wait %d frames', mp[0])
        when 16
          @arg += 'turn down'
        when 17
          @arg += 'turn left'
        when 18
          @arg += 'turn right'
        when 19
          @arg += 'turn up'
        when 20
          @arg += 'turn 90 degrees right'
        when 21
          @arg += 'turn 90 degrees left'
        when 22
          @arg += 'turn 180 degrees'
        when 23
          @arg += 'turn 90 degrees right or left'
        when 24
          @arg += 'turn at random'
        when 25
          @arg += 'turn toward player'
        when 26
          @arg += 'turn away from player'
        when 27
          @sv1 = get_switch(mp[0])
          @arg += sprintf('%s ON', @sv1)
          @swvar_export = true
        when 28
          @sv1 = get_switch(mp[0])
          @arg += sprintf('%s OFF', @sv1)
          @swvar_export = true
        when 29
          @arg += sprintf('change speed to %d', mp[0])
        when 30
          @arg += sprintf('change frequency to %d', mp[0])
        when 31
          @arg += 'walking animation on'
        when 32
          @arg += 'walking animation off'
        when 33
          @arg += 'stepping animation on'
        when 34
          @arg += 'stepping animation off'
        when 35
          @arg += 'direction fix on'
        when 36
          @arg += 'direction fix off'
        when 37
          @arg += 'through on'
        when 38
          @arg += 'through off'
        when 39
          @arg += 'transparent on'
        when 40
          @arg += 'transparent off'
        when 41
          @arg += sprintf('change graphic to %s index %s', mp[0], mp[1].to_s)
        when 42
          @arg += sprintf('change opacity to %d', mp[0])
        when 43
          @arg += sprintf('change blending to %s', ['normal', 'add', 'sub'][mp[0]])
        when 44
          @arg += sprintf('play SE %s;  Volume %d  Pitch %d', mp[0].name, mp[0].volume, mp[0].pitch)
        when 45
          @arg += sprintf('script: %s', mp[0])
        end
        self.export_command
      end
    end
    @skip_export = true
  end
  #--------------------------------------------------------------------------
  # * Getting On and Off Vehicles
  #--------------------------------------------------------------------------
  def self.command_206
    @cmd = "Getting On and Off Vehicles"
    @arg = "Get on/off Vehicle"
  end
  #--------------------------------------------------------------------------
  # * Change Transparency
  #--------------------------------------------------------------------------
  def self.command_211
    @cmd = "Change Transparency"
    @arg = sprintf('Transparency %s', (@params[0] == 0 ? 'ON' : 'OFF'))
  end
  #--------------------------------------------------------------------------
  # * Show Animation
  #--------------------------------------------------------------------------
  def self.command_212
    @cmd = "Show Animation"
    @arg = sprintf('%d (%s) on %s', @params[1], self.animation_name(@params[1]),
      self.get_character(@params[0]))
    @arg += ' (wait)' if @params[2]
  end
  #--------------------------------------------------------------------------
  # * Show Balloon Icon
  #--------------------------------------------------------------------------
  def self.command_213
    @cmd = "Show Balloon Icon"
    @arg = sprintf('%d (%s) on %s', @params[1],
      ['Exclamation', 'Question', 'Music Note', 'Heart', 'Anger', 'Sweat',
      'Cobweb', 'Silence', 'Light Bulb', 'Zzz'][@params[1]-1],
      self.get_character(@params[0]))
    @arg += ' (wait)' if @params[2]
  end
  #--------------------------------------------------------------------------
  # * Temporarily Erase Event
  #--------------------------------------------------------------------------
  def self.command_214
    @cmd = "Temporarily Erase Event"
    @arg = 'Erase Event'
  end
  #--------------------------------------------------------------------------
  # * Change Player Followers
  #--------------------------------------------------------------------------
  def self.command_216
    @cmd = "Change Player Followers"
    @arg = @params[0] == 0 ? "make visible" : "make invisible"
  end
  #--------------------------------------------------------------------------
  # * Gather Followers
  #--------------------------------------------------------------------------
  def self.command_217
    @cmd = "Gather Followers"
    @arg = 'Gather Followers'
  end
  #--------------------------------------------------------------------------
  # * Fadeout Screen
  #--------------------------------------------------------------------------
  def self.command_221
    @cmd = "Fadeout Screen"
    @arg = '30 frames'
  end
  #--------------------------------------------------------------------------
  # * Fadein Screen
  #--------------------------------------------------------------------------
  def self.command_222
    @cmd = "Fadein Screen"
    @arg = '30 frames'
  end
  #--------------------------------------------------------------------------
  # * Tint Screen
  #--------------------------------------------------------------------------
  def self.command_223
    @cmd = "Tint Screen"
    @arg = sprintf('%s in %d frames', @params[0].to_s, @params[1])
    @arg += ' (wait)' if @params[2]
  end
  #--------------------------------------------------------------------------
  # * Screen Flash
  #--------------------------------------------------------------------------
  def self.command_224
    @cmd = "Screen Flash"
    @arg = sprintf('%s for %d frames', @params[0].to_s, @params[1])
    @arg += ' (wait)' if @params[2]
  end
  #--------------------------------------------------------------------------
  # * Screen Shake
  #--------------------------------------------------------------------------
  def self.command_225
    @cmd = "Screen Shake"
    @arg = sprintf('Power %d  Speed %d  for %d frames', @params[0], @params[1],
      @params[2])
    @arg += ' (wait)' if @params[3]
  end
  #--------------------------------------------------------------------------
  # * Wait
  #--------------------------------------------------------------------------
  def self.command_230
    @cmd = "Wait"
    @arg = sprintf("%d frames", @params[0])
  end
  #--------------------------------------------------------------------------
  # * Show Picture
  #--------------------------------------------------------------------------
  def self.command_231
    @cmd = "Show Picture"
    @arg = sprintf("%d (%s) origin %s at %s, opacity %d", @params[0], @params[1],
     (@params[2] == 0 ? "top left" : "center"), self.get_loc(@params[4], @params[5],
     @params[3] == 0), @params[8])
  end
  #--------------------------------------------------------------------------
  # * Move Picture
  #--------------------------------------------------------------------------
  def self.command_232
    @cmd = "Move Picture"
    @arg = sprintf("%d origin %s to %s, opacity %d, duration %d", @params[0], 
      (@params[2] == 0 ? "top left" : "center"), self.get_loc(@params[4], @params[5],
      @params[3] == 0), @params[8], @params[10])
    @arg += ' (wait)' if @params[11]
  end
  #--------------------------------------------------------------------------
  # * Rotate Picture
  #--------------------------------------------------------------------------
  def self.command_233
    @cmd = "Rotate Picture"
    @arg = sprintf('%d at speed %d', @params[0], @params[1])
  end
  #--------------------------------------------------------------------------
  # * Tint Picture
  #--------------------------------------------------------------------------
  def self.command_234
    @cmd = "Tint Picture"
    @arg = sprintf('%d to tone %s in %d frames', @params[0], @params[1].to_s, @params[2])
    @arg += ' (wait)' if @params[3]
  end
  #--------------------------------------------------------------------------
  # * Erase Picture
  #--------------------------------------------------------------------------
  def self.command_235
    @cmd = "Erase Picture"
    @arg = @params[0].to_s
  end
  #--------------------------------------------------------------------------
  # * Set Weather
  #--------------------------------------------------------------------------
  def self.command_236
    @cmd = "Set Weather"
    @arg = sprintf('%s  Power %d  Time %d frames', @params[0],
      @params[1], @params[2])
    @arg += ' (wait)' if @params[3]
  end
  #--------------------------------------------------------------------------
  # * Play BGM
  #--------------------------------------------------------------------------
  def self.command_241
    @cmd = "Play BGM"
    @arg = self.get_audio(@params[0])
  end
  #--------------------------------------------------------------------------
  # * Fadeout BGM
  #--------------------------------------------------------------------------
  def self.command_242
    @cmd = "Fadeout BGM"
    @arg = sprintf('%d seconds', @params[0])
  end
  #--------------------------------------------------------------------------
  # * Save BGM
  #--------------------------------------------------------------------------
  def self.command_243
    @cmd = "Save BGM"
    @arg = 'Save BGM'
  end
  #--------------------------------------------------------------------------
  # * Resume BGM
  #--------------------------------------------------------------------------
  def self.command_244
    @cmd = "Resume BGM"
    @arg = 'Resume BGM'
  end
  #--------------------------------------------------------------------------
  # * Play BGS
  #--------------------------------------------------------------------------
  def self.command_245
    @cmd = "Play BGS"
    @arg = self.get_audio(@params[0])
  end
  #--------------------------------------------------------------------------
  # * Fadeout BGS
  #--------------------------------------------------------------------------
  def self.command_246
    @cmd = "Fadeout BGS"
    @arg = sprintf('%d seconds', @params[0])
  end
  #--------------------------------------------------------------------------
  # * Play ME
  #--------------------------------------------------------------------------
  def self.command_249
    @cmd = "Play ME"
    @arg = self.get_audio(@params[0])
  end
  #--------------------------------------------------------------------------
  # * Play SE
  #--------------------------------------------------------------------------
  def self.command_250
    @cmd = "Play SE"
    @arg = self.get_audio(@params[0])
  end
  #--------------------------------------------------------------------------
  # * Stop SE
  #--------------------------------------------------------------------------
  def self.command_251
    @cmd = "Stop SE"
    @arg = 'Stop SE'
  end
  #--------------------------------------------------------------------------
  # * Play Movie
  #--------------------------------------------------------------------------
  def self.command_261
    @cmd = "Play Movie"
    @arg = @params[0]
  end
  #--------------------------------------------------------------------------
  # * Change Map Name Display
  #--------------------------------------------------------------------------
  def self.command_281
    @cmd = "Change Map Name Display"
    @arg = @params[0] == 0 ? "visible" : "hidden"
  end
  #--------------------------------------------------------------------------
  # * Change Tileset
  #--------------------------------------------------------------------------
  def self.command_282
    @cmd = "Change Tileset"
    @arg = sprintf('%d (%s)', @params[0], self.tileset_name(@params[0]))
  end
  #--------------------------------------------------------------------------
  # * Change Battle Background
  #--------------------------------------------------------------------------
  def self.command_283
    @cmd = "Change Battle Background"
    @arg = sprintf('Ground: %s  Walls: %s', @params[0], @params[1])
  end
  #--------------------------------------------------------------------------
  # * Change Parallax Background
  #--------------------------------------------------------------------------
  def self.command_284
    @cmd = "Change Parallax Background"
    @arg = @params[0]
    @arg += sprintf(' (loop horizontal%s)', 
      (@params[3] > 0 ? " [scroll " + @params[3].to_s + "]" : "")) if @params[1]
    @arg += sprintf(' (loop vertical%s)', 
      (@params[4] > 0 ? " [scroll " + @params[4].to_s + "]" : "")) if @params[2]
  end
  #--------------------------------------------------------------------------
  # * Get Location Info
  #--------------------------------------------------------------------------
  def self.command_285
    @cmd = "Get Location Info"
    @sv1 = get_variable(@params[0])
    @arg = sprintf('Tile %s, %s into %s', self.get_loc(@params[3], @params[4], @params[2] == 0),
      ['Terrain Tag', 'Event ID', 'Tile ID (Layer 1)', 'Tile ID (Layer 2)',
      'Tile ID (Layer 3)', 'Region ID'][@params[1]], @sv1)
    @swvar_export = true
  end
  #--------------------------------------------------------------------------
  # * Battle Processing
  #--------------------------------------------------------------------------
  def self.command_301
    @cmd = "Battle Processing"
    @sv1 = get_variable(@params[1]) if @params[0] == 1
    @arg = @params[0] == 0 ? sprintf('Troop %d (%s)', @params[1], 
      self.troop_name(@params[1])) : @params[0] == 1 ? sprintf('Troop from %s',
      @sv1) : 'map-designated troop'
    @swvar_export = @params[0] == 1
  end
  #--------------------------------------------------------------------------
  # * If Win
  #--------------------------------------------------------------------------
  def self.command_601
    @cmd = "If Win"
    @arg = 'if win'
  end
  #--------------------------------------------------------------------------
  # * If Escape
  #--------------------------------------------------------------------------
  def self.command_602
    @cmd = "If Escape"
    @arg = 'if escape'
  end
  #--------------------------------------------------------------------------
  # * If Lose
  #--------------------------------------------------------------------------
  def self.command_603
    @cmd = "If Lose"
    @arg = 'if lose'
  end
  #--------------------------------------------------------------------------
  # * Shop Processing
  #--------------------------------------------------------------------------
  def self.command_302
    @cmd = "Shop Processing"
    if @params[4] 
      @arg = "(purchase only)"
      self.export_command
    end
    goods = @params
    item = goods[0] == 0 ? $data_items[goods[1]] : goods[0] == 1 ? $data_weapons[goods[1]] :
      $data_armors[goods[1]]
    if item
      @arg = sprintf('%s %d (%s)', ['Item', 'Weapon', 'Armor'][goods[0]], item.id, item.name)
      @arg += goods[2] == 0 ? sprintf(' : %d', item.price) : sprintf(' : %d (price override)',
        goods[3])
    else
      @arg = sprintf('%s %d (%s)', ['Item', 'Weapon', 'Armor'][goods[0]], goods[1], 'undefined')
    end
    self.export_command
    
    while next_event_code == 605
      @cmdline += 1
      goods = @list[@cmdline].parameters
      item = goods[0] == 0 ? $data_items[goods[1]] : goods[0] == 1 ? $data_weapons[goods[1]] :
        $data_armors[goods[1]]
      if item
        @arg = sprintf('%s %d (%s)', ['Item', 'Weapon', 'Armor'][goods[0]], item.id, item.name)
        @arg += goods[2] == 0 ? sprintf(' : %d', item.price) : sprintf(' : %d (price override)',
          goods[3])
      else
        @arg = sprintf('%s %d (%s)', ['Item', 'Weapon', 'Armor'][goods[0]], goods[1], 'undefined')
      end
      self.export_command
    end
    @skip_export = true
  end
  #--------------------------------------------------------------------------
  # * Name Input Processing
  #--------------------------------------------------------------------------
  def self.command_303
    @cmd = "Name Input Processing"
    @arg = sprintf('Actor %d (%s), %d characters', @params[0], self.actor_name(@params[0]),
      @params[1])
  end
  #--------------------------------------------------------------------------
  # * Change HP
  #--------------------------------------------------------------------------
  def self.command_311
    @cmd = "Change HP"
    @arg = sprintf('%s %s', 
      self.get_actor(@params[0], @params[1]),
      self.operate_value(@params[2], @params[4], @params[3] == 0))
    @arg += ' (allow knockout)' if @params[5]
  end
  #--------------------------------------------------------------------------
  # * Change MP
  #--------------------------------------------------------------------------
  def self.command_312
    @cmd = "Change MP"
    @arg = sprintf('%s %s', self.get_actor(@params[0], @params[1]),
      self.operate_value(@params[2], @params[4], @params[3] == 0))
  end
  #--------------------------------------------------------------------------
  # * Change State
  #--------------------------------------------------------------------------
  def self.command_313
    @cmd = "Change State"
    @arg = sprintf('%s %s %d (%s)', self.get_actor(@params[0], @params[1]),
      (@params[2] == 0 ? '+' : '-'), @params[3], self.state_name(@params[3]))
  end
  #--------------------------------------------------------------------------
  # * Recover All
  #--------------------------------------------------------------------------
  def self.command_314
    @cmd = "Recover All"
    @arg = self.get_actor(@params[0], @params[1])
  end
  #--------------------------------------------------------------------------
  # * Change EXP
  #--------------------------------------------------------------------------
  def self.command_315
    @cmd = "Change EXP"
    @arg = sprintf('%s %s', self.get_actor(@params[0], @params[1]),
      self.operate_value(@params[2], @params[4], @params[3] == 0))
    @arg += ' (show level up message)' if @params[5]
  end
  #--------------------------------------------------------------------------
  # * Change Level
  #--------------------------------------------------------------------------
  def self.command_316
    @cmd = "Change Level"
    @arg = sprintf('%s %s', self.get_actor(@params[0], @params[1]),
      self.operate_value(@params[2], @params[4], @params[3] == 0))
    @arg += ' (show level up message)' if @params[5]
  end
  #--------------------------------------------------------------------------
  # * Change Parameters
  #--------------------------------------------------------------------------
  def self.command_317
    @cmd = "Change Parameters"
    @arg = sprintf('%s %s %s', self.get_actor(@params[0], @params[1]),
      ['MHP', 'MMP', 'ATK', 'DEF', 'MAT', 'MDF', 'AGI', 'LUK'][@params[2]],
      self.operate_value(@params[3], @params[5], @params[4] == 0))
  end
  #--------------------------------------------------------------------------
  # * Change Skills
  #--------------------------------------------------------------------------
  def self.command_318
    @cmd = "Change Skills"
    @arg = sprintf('%s %s %d (%s)', self.get_actor(@params[0], @params[1]),
      (@params[2] == 0 ? "learn" : "forget"), @params[3],
      self.skill_name(@params[3]))
  end
  #--------------------------------------------------------------------------
  # * Change Equipment
  #--------------------------------------------------------------------------
  def self.command_319
    @cmd = "Change Equipment"
    @arg += sprintf('%s %s %d %s',
      self.get_actor(0, @params[0]), $data_system.terms.etypes[@params[1]],
      @params[2], (@params[2] == 0 ? "None" : (@params[1] == 0 ? 
      self.weapon_name(@params[2]) : self.armor_name(@params[2]))))
  end
  #--------------------------------------------------------------------------
  # * Change Name
  #--------------------------------------------------------------------------
  def self.command_320
    @text_export = true
    @cmd = "Change Name"
    @arg = sprintf('Actor %d (%s) to %s', @params[0], self.actor_name(@params[0]),
      @params[1])
  end
  #--------------------------------------------------------------------------
  # * Change Class
  #--------------------------------------------------------------------------
  def self.command_321
    @cmd = "Change Class"
    @arg = sprintf('Actor %d (%s) to %d (%s)', @params[0],
      $data_actors[@params[0]].name, @params[1], self.class_name(@params[1]))
  end
  #--------------------------------------------------------------------------
  # * Change Actor Graphic
  #--------------------------------------------------------------------------
  def self.command_322
    @cmd = "Change Actor Graphic"
    @arg = sprintf('Actor %d (%s)  Character %s (%d)  Face %s (%d)',
      @params[0], self.actor_name(@params[0]), @params[1], @params[2],
      @params[3], @params[4])
  end
  #--------------------------------------------------------------------------
  # * Change Vehicle Graphic
  #--------------------------------------------------------------------------
  def self.command_323
    @cmd = "Change Vehicle Graphic"
    @arg = sprintf('%s  Character %s (%d)',
      self.get_vehicle(@params[0]), @params[1], @params[2])
  end
  #--------------------------------------------------------------------------
  # * Change Nickname
  #--------------------------------------------------------------------------
  def self.command_324
    @text_export = true
    @cmd = "Change Nickname"
    @arg = sprintf('Actor %d (%s) to %s', @params[0], $data_actors[@params[0]].name,
      @params[1])
  end
  #--------------------------------------------------------------------------
  # * Change Enemy HP
  #--------------------------------------------------------------------------
  def self.command_331
    @cmd = "Change Enemy HP"
    @arg = sprintf('%s %s', self.get_enemy(@params[0]),
      self.operate_value(@params[1], @params[3], @params[2] == 0))
    @arg += ' (allow knockout)' if @params[4]
  end
  #--------------------------------------------------------------------------
  # * Change Enemy MP
  #--------------------------------------------------------------------------
  def self.command_332
    @cmd = "Change Enemy MP"
    @arg = sprintf('%s %s', self.get_enemy(@params[0]),
      self.operate_value(@params[1], @params[3], @params[2] == 0))
  end
  #--------------------------------------------------------------------------
  # * Change Enemy State
  #--------------------------------------------------------------------------
  def self.command_333
    @cmd = "Change Enemy State"
    @arg = sprintf('%s %s %d (%s)', self.get_enemy(@params[0]),
      (@params[1] == 0 ? '+' : '-'), @params[2], self.state_name(@params[2]))
  end
  #--------------------------------------------------------------------------
  # * Enemy Recover All
  #--------------------------------------------------------------------------
  def self.command_334
    @cmd = "Enemy Recover All"
    @arg = self.get_enemy(@params[0])
  end
  #--------------------------------------------------------------------------
  # * Enemy Appear
  #--------------------------------------------------------------------------
  def self.command_335
    @cmd = "Enemy Appear"
    @arg = self.get_enemy(@params[0])
  end
  #--------------------------------------------------------------------------
  # * Enemy Transform
  #--------------------------------------------------------------------------
  def self.command_336
    @cmd = "Enemy Transform"
    @arg = sprintf('%s to %d (%s)', self.get_enemy(@params[0]), @params[1],
      self.enemy_name(@params[1]))
  end
  #--------------------------------------------------------------------------
  # * Show Battle Animation
  #--------------------------------------------------------------------------
  def self.command_337
    @cmd = "Show Battle Animation"
    @arg = sprintf('%d (%s) on %s', @params[1], self.animation_name(@params[1]),
      self.get_enemy(@params[0]))
  end
  #--------------------------------------------------------------------------
  # * Force Action
  #--------------------------------------------------------------------------
  def self.command_339
    @cmd = "Force Action"
    @arg = sprintf('%s skill %d (%s) on target %s',
      (@params[0] == 0 ? self.get_enemy(@params[1]) : self.get_actor(0, @params[1])),
      @params[2], self.skill_name(@params[2]), (@params[3] == -2 ? 'last target' :
      (@params[3] == -1 ? 'random target' : @params[3].to_s)))
  end
  #--------------------------------------------------------------------------
  # * Abort Battle
  #--------------------------------------------------------------------------
  def self.command_340
    @cmd = "Abort Battle"
    @arg = 'Abort'
  end
  #--------------------------------------------------------------------------
  # * Open Menu Screen
  #--------------------------------------------------------------------------
  def self.command_351
    @cmd = "Open Menu Screen"
    @arg = 'open menu screen'
  end
  #--------------------------------------------------------------------------
  # * Open Save Screen
  #--------------------------------------------------------------------------
  def self.command_352
    @cmd = "Open Save Screen"
    @arg = 'open save screen'
  end
  #--------------------------------------------------------------------------
  # * Game Over
  #--------------------------------------------------------------------------
  def self.command_353
    @cmd = "Game Over"
    @arg = 'game over'
  end
  #--------------------------------------------------------------------------
  # * Return to Title Screen
  #--------------------------------------------------------------------------
  def self.command_354
    @cmd = "Return to Title Screen"
    @arg = 'return to title screen'
  end
  #--------------------------------------------------------------------------
  # * Script
  #--------------------------------------------------------------------------
  def self.command_355
    @cmd = "Script"
    @arg = @params[0]
  end
  def self.command_655
    @cmd = "Script"
    @arg = @params[0]
  end
  
  def self.export_condition
    while @arg.gsub!(/  /) { " " } != nil
    end
    
    @expline += 1
    
    text = sprintf("%d%s%d%s%s%s%s%s%s%s%d%s%s%s%s%s%s%s",
      @expline, @cb, @event_seq, @cb, @event_type, @cb, @event_source, @cb,
      @event_tab, @cb, @line, @cb, 'Condition', @cb, @cmd, @cb, @arg, @lb)
      
    @file_all.print(text)
    
    if @swvar_export
      text = sprintf("%d%s%d%s%s%s%s%s%s%s%d%s%s%s%s%s%s%s%s%s",
        @expline, @cb, @event_seq, @cb, @event_type, @cb, @event_source, @cb,
        @event_tab, @cb, @line, @cb, 'Condition', @cb, @cmd, @cb, @sv1, @cb, @arg, @lb)
      @file_swvar.print(text) 
      if @sv2
        text = sprintf("%d%s%d%s%s%s%s%s%s%s%d%s%s%s%s%s%s%s%s%s",
          @expline, @cb, @event_seq, @cb, @event_type, @cb, @event_source, @cb,
          @event_tab, @cb, @line, @cb, 'Condition', @cb, @cmd, @cb, @sv2, @cb, @arg, @lb)
        @file_swvar.print(text) 
      end
      if @sv3
        text = sprintf("%d%s%d%s%s%s%s%s%s%s%d%s%s%s%s%s%s%s%s%s",
          @expline, @cb, @event_seq, @cb, @event_type, @cb, @event_source, @cb,
          @event_tab, @cb, @line, @cb, 'Condition', @cb, @cmd, @cb, @sv3, @cb, @arg, @lb)
        @file_swvar.print(text) 
      end
    end
  end
    
    
  
  def self.export_command
    # get rid of any double spaces
    while @arg.gsub!(/  /) { " " } != nil
    end
    
    @expline += 1
    
    indchar = INDENT ? @ind * @indent : ""
    
    text = sprintf("%d%s%d%s%s%s%s%s%s%s%d%s%d%s%s%s%s%s%s",
      @expline, @cb, @event_seq, @cb, @event_type, @cb, @event_source, @cb,
      @event_tab, @cb, @line, @cb, @command.code, @cb, @cmd, @cb, indchar, @arg, @lb)
      
    @file_all.print(text)
    @file_text.print(text) if @text_export
    if @swvar_export
      text = sprintf("%d%s%d%s%s%s%s%s%s%s%d%s%d%s%s%s%s%s%s%s",
        @expline, @cb, @event_seq, @cb, @event_type, @cb, @event_source, @cb,
        @event_tab, @cb, @line, @cb, @command.code, @cb, @cmd, @cb, @sv1, @cb, @arg, @lb)
      @file_swvar.print(text) 
      if @sv2
        text = sprintf("%d%s%d%s%s%s%s%s%s%s%d%s%d%s%s%s%s%s%s%s",
          @expline, @cb, @event_seq, @cb, @event_type, @cb, @event_source, @cb,
          @event_tab, @cb, @line, @cb, @command.code, @cb, @cmd, @cb, @sv2, @cb, @arg, @lb)
        @file_swvar.print(text) 
      end
      if @sv3
        text = sprintf("%d%s%d%s%s%s%s%s%s%s%d%s%d%s%s%s%s%s%s%s",
          @expline, @cb, @event_seq, @cb, @event_type, @cb, @event_source, @cb,
          @event_tab, @cb, @line, @cb, @command.code, @cb, @cmd, @cb, @sv3, @cb, @arg, @lb)
        @file_swvar.print(text) 
      end
    end
  end
end
    
EVExport.export