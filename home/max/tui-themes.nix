# home/max/tui-themes.nix — Gruvbox Material for terminal apps that bring their
# own colours and have no Stylix target, so kitty's palette (modules/home/apps.nix)
# doesn't reach them on its own.
{
  xdg.configFile = {
    # VisiData's curses colours can't take hex (and pick the 256-colour value
    # first when a default lists both, e.g. '68 blue'), so this theme uses the
    # 16 ANSI names only and lets kitty's palette supply the Gruvbox accents
    # (black, 8, white and 15 stay kitty's neutral greys). color_default "" leaves
    # the background unpainted so kitty's translucency shows through. A
    # registered theme rather than bare options, so `theme-input` can switch
    # away and back.
    "visidata/config.py".text = ''
      vd.themes['gruvbox-material'] = dict(
          color_default="",
          color_default_hdr='bold',
          color_bottom_hdr='underline',
          color_column_sep='8',
          color_current_col='bold on black',
          color_key_col='cyan',
          color_hidden_col='8',
          color_selected_row='yellow',
          color_code='bold 15 on black',
          color_keystrokes='bold 15 on black',
          color_edit_cell='black on blue',
          color_edit_unfocused='white on black',
          color_error='red',
          color_warning='yellow',
          color_working='green',
          color_note_row='yellow',
          color_note_type='yellow',
          color_status='bold on black',
          color_active_status='black on blue',
          color_inactive_status='8 on black',
          color_menu='black on blue',
          color_menu_help='black italic on blue',
          color_menu_active='yellow on black',
          color_menu_spec='black on green',
          color_cmdpalette='black on cyan',
          color_sidebar='black on blue',
          color_graph_hidden='8',
          color_guide_unwritten='8',
          color_longname_guide='8',
          color_git_untracked='8',
          color_git_unstaged_del='black on red',
          plot_colors='green red yellow cyan magenta blue white',
      )
      options.theme = 'gruvbox-material'
    '';
  };
}
