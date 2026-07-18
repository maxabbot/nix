// SliderRow.qml — Label + slider + value display, shared by AudioMixer and ControlCenter.
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

RowLayout {
    id: root

    property string label: ""
    property real   value: 0.5
    property real   from:  0.0
    property real   to:    1.0
    property string unit:  "%"

    signal moved(real newValue)

    spacing: 8

    Text {
        text: root.label
        color: Theme.gray
        font.pixelSize: 12
        font.family: Theme.font
        Layout.minimumWidth: 64
    }

    Slider {
        id: sl
        Layout.fillWidth: true
        from: root.from
        to: root.to
        value: root.value
        onMoved: root.moved(value)

        background: Rectangle {
            x: sl.leftPadding
            y: sl.topPadding + sl.availableHeight / 2 - height / 2
            width: sl.availableWidth
            height: 4
            radius: 2
            color: Theme.border

            Rectangle {
                width: sl.visualPosition * parent.width
                height: parent.height
                radius: 2
                color: Theme.accent
            }
        }

        handle: Rectangle {
            x: sl.leftPadding + sl.visualPosition * (sl.availableWidth - width)
            y: sl.topPadding + sl.availableHeight / 2 - height / 2
            width: 14
            height: 14
            radius: 7
            color: sl.pressed ? Theme.accentBright : Theme.accent
            Behavior on color { ColorAnimation { duration: 80 } }
        }
    }

    Text {
        // "%" sliders carry a 0–1 fraction; other units carry an absolute value.
        text: (root.unit === "%" ? Math.round(root.value * 100) : Math.round(root.value)) + root.unit
        color: Theme.fg
        font.pixelSize: 11
        font.family: Theme.font
        Layout.minimumWidth: 36
        horizontalAlignment: Text.AlignRight
    }
}
