{ lib, pkgs, ... }:
let
  # LibreOffice rewrites registrymodifications.xcu on exit, so the file can't be a
  # store symlink. Instead these keys are upserted into it on each activation
  # (idempotent; other settings LibreOffice wrote are left alone).
  settings = [
    # Tabbed ribbon (Home/Insert/Layout…) instead of the classic toolbars
    (tabbed "Writer")
    (tabbed "Calc")
    (tabbed "Impress")
    (tabbed "Draw")
    # New documents save as .docx/.xlsx/.pptx
    (factory "text.TextDocument" "MS Word 2007 XML")
    (factory "sheet.SpreadsheetDocument" "Calc MS Excel 2007 XML")
    (factory "presentation.PresentationDocument" "Impress MS PowerPoint 2007 XML")
    # …and don't nag about "Keep current format?" every save
    {
      path = "/org.openoffice.Office.Common/Save/Document";
      name = "WarnAlienFormat";
      value = "false";
    }
  ];
  tabbed = app: {
    path = "/org.openoffice.Office.UI.ToolbarMode/Applications/org.openoffice.Office.UI.ToolbarMode:Application['${app}']";
    name = "Active";
    value = "notebookbar.ui";
  };
  factory = name: filter: {
    path = "/org.openoffice.Setup/Office/Factories/org.openoffice.Setup:Factory['com.sun.star.${name}']";
    name = "ooSetupFactoryDefaultFilter";
    value = filter;
  };
  settingsFile = pkgs.writeText "libreoffice-settings.json" (builtins.toJSON settings);
  merge = pkgs.writeText "libreoffice-merge.py" ''
    import json, os, sys
    import xml.etree.ElementTree as ET

    OOR = "http://openoffice.org/2001/registry"
    XS = "http://www.w3.org/2001/XMLSchema"
    ET.register_namespace("oor", OOR)
    ET.register_namespace("xs", XS)
    ET.register_namespace("xsi", "http://www.w3.org/2001/XMLSchema-instance")

    path = sys.argv[2]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path):
        tree = ET.parse(path)
        root = tree.getroot()
    else:
        root = ET.Element("{%s}items" % OOR)
        tree = ET.ElementTree(root)

    for s in json.load(open(sys.argv[1])):
        item = next((i for i in root.findall("item")
                     if i.get("{%s}path" % OOR) == s["path"]
                     and i.find("prop") is not None
                     and i.find("prop").get("{%s}name" % OOR) == s["name"]), None)
        if item is None:
            item = ET.SubElement(root, "item", {"{%s}path" % OOR: s["path"]})
            ET.SubElement(item, "prop", {"{%s}name" % OOR: s["name"], "{%s}op" % OOR: "fuse"})
        prop = item.find("prop")
        val = prop.find("value")
        if val is None:
            val = ET.SubElement(prop, "value")
        val.text = s["value"]

    tree.write(path, encoding="UTF-8", xml_declaration=True)
  '';
in
{
  # Metric-compatible Calibri/Cambria replacements (LibreOffice maps them
  # automatically), so .docx files from Office keep their layout.
  home.packages = [
    pkgs.carlito
    pkgs.caladea
  ];

  home.activation.libreofficeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! ${pkgs.procps}/bin/pgrep -x soffice.bin >/dev/null; then
      run ${pkgs.python3}/bin/python3 ${merge} ${settingsFile} "$HOME/.config/libreoffice/4/user/registrymodifications.xcu"
    else
      echo "LibreOffice is running; skipping settings merge (it would overwrite them on exit)"
    fi
  '';
}
