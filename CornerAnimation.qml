import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons

// One-shot desktop animation for the corner menu: a mouse darts out, visits
// another window first, then changes course and runs all over the screen —
// leaving a fading stripe as it goes — until it dives into the picked corner
// and the cat jumps. About five seconds. Click-through: the surface has an
// empty input region, so it never blocks the desktop while it plays.
Item {
  id: animRoot

  property string corner: "tl"
  property int detourX: 0
  property int detourY: 0
  property int targetX: 0
  property int targetY: 0
  property int screenW: 0
  property int screenH: 0

  property bool playing: false
  property bool jumpPhase: false

  // Scene geometry — computed from the corner so the replay mirrors for
  // left/right and flips over for the bottom corners.
  readonly property bool toRight: corner === "tr" || corner === "br"
  readonly property bool toBottom: corner === "bl" || corner === "br"
  readonly property color trailColor: Commons.Color.accent
  readonly property color mouseColor: "#ddd6c4"
  readonly property color catColor: Commons.Color.accent

  // The chase starts at the far side of the screen, a little under centre,
  // then sweeps high across the opposite side before diving into the grip's
  // corner — the detour through another window comes in between.
  readonly property real startX: screenW * (toRight ? 0.30 : 0.70)
  readonly property real startY: screenH * (toBottom ? 0.48 : 0.52)
  readonly property real wanderX: screenW * (toRight ? 0.18 : 0.82)
  readonly property real wanderY: screenH * (toBottom ? 0.82 : 0.18)
  readonly property real mouseEndX: targetX
  readonly property real mouseEndY: targetY
  readonly property real landX: toRight ? targetX - 42 : targetX + 42
  readonly property real landY: toBottom
    ? Math.min(screenH - 24, targetY - 22)
    : Math.max(24, targetY + 22)

  function play(c, dx, dy, tx, ty, w, h) {
    console.info("corner-anim play", c, "detour", dx, dy, "target", tx, ty)
    corner = c
    detourX = dx
    detourY = dy
    targetX = tx
    targetY = ty
    screenW = w
    screenH = h

    master.stop()
    // Reset everything the last run left bound or animated.
    jumpPhase = false
    opacity = 1.0
    mouseItem.scale = 1.0
    mouseItem.opacity = 1.0
    catItem.scale = 1.0
    catItem.rotation = 0.0
    mouseIp.progress = 0
    stampTimer.clear()
    playing = true
    master.restart()
  }

  function finish() {
    playing = false
    jumpPhase = false
    stampTimer.clear()
  }

  SequentialAnimation {
    id: master
    running: false

    ParallelAnimation {
      // chase: the mouse runs, the cat trails 16 % of the path behind
      NumberAnimation {
        target: mouseIp
        property: "progress"
        from: 0
        to: 1
        duration: 3000
      }
    }
    // the mouse dives into the corner and is gone
    ParallelAnimation {
      NumberAnimation {
        target: mouseItem
        property: "scale"
        from: 1.0
        to: 0.1
        duration: 150
      }
      NumberAnimation {
        target: mouseItem
        property: "opacity"
        from: 1.0
        to: 0.0
        duration: 150
      }
    }
    ScriptAction {
      script: {
        animRoot.jumpStartX = catRunIp.x
        animRoot.jumpStartY = catRunIp.y
        animRoot.jumpPhase = true
      }
    }
    ParallelAnimation {
      // the jump: a slow-out hop so the arc reads as one leap
      NumberAnimation {
        target: jumpIp
        property: "progress"
        from: 0
        to: 1
        duration: 620
        easing.type: Easing.OutQuad
      }
      // squash and stretch along the leap
      SequentialAnimation {
        NumberAnimation {
          target: catItem
          property: "scale"
          from: 1.0
          to: 1.3
          duration: 280
          easing.type: Easing.OutQuad
        }
        NumberAnimation {
          target: catItem
          property: "scale"
          from: 1.3
          to: 1.0
          duration: 320
          easing.type: Easing.InQuad
        }
      }
    }
    // the cat inspects the corner it just caught the mouse in
    SequentialAnimation {
      NumberAnimation {
        target: catItem
        property: "rotation"
        to: animRoot.toRight ? -5 : 5
        duration: 110
        easing.type: Easing.InOutQuad
      }
      NumberAnimation {
        target: catItem
        property: "rotation"
        to: animRoot.toRight ? 5 : -5
        duration: 110
        easing.type: Easing.InOutQuad
      }
      NumberAnimation {
        target: catItem
        property: "rotation"
        to: 0
        duration: 90
        easing.type: Easing.InOutQuad
      }
    }
    PropertyAnimation {
      target: animRoot
      property: "opacity"
      to: 0
      duration: 550
    }
    ScriptAction {
      script: animRoot.finish()
    }
  }      // trail of the running mouse: stripes fade where it passed
      Component {
    id: trailPiece

    Rectangle {
      width: 15
      height: 4
      radius: 2
      color: animRoot.trailColor
      opacity: 0.6

      SequentialAnimation on opacity {
        PauseAnimation {
          duration: 500
        }
        NumberAnimation {
          to: 0
          duration: 1400
          easing.type: Easing.OutQuad
        }
      }
      Timer {
        interval: 1950
        running: true
        onTriggered: destroy()
      }
    }
  }

  Timer {
    id: stampTimer
    interval: 55
    running: animRoot.playing
    repeat: true
    onTriggered: stamp()
    function clear() {
      for (var i = animRoot.children.length - 1; i >= 0; i--) {
        var child = animRoot.children[i]
        if (child.objectName === "trail") child.destroy()
      }
    }
    function stamp() {
      if (!animRoot.playing || animRoot.jumpPhase
          || mouseIp.progress <= 0 || mouseIp.progress >= 1) return
      var piece = trailPiece.createObject(animRoot, {
        objectName: "trail",
        x: mouseIp.x - 7,
        y: mouseIp.y - 2
      })
      if (Math.random() < 0.35 && piece) piece.width = 9   // uneven dashes, like a scurry
    }
  }

  // ---------------------------------------------------------------- geometry
  // One path each, in three legs: out to another window, a change of course
  // that sweeps high across the opposite side of the screen, then down into
  // the grip's corner. The mouse runs it all; the cat's progress is the
  // mouse's minus a fixed head start, and the jump reuses the cat's last
  // on-path position as its take-off.
  Path {
    id: runPath
    startX: animRoot.startX
    startY: animRoot.startY

    // leg 1: out to the other window
    PathQuad {
      x: animRoot.detourX
      y: animRoot.detourY
      controlX: (animRoot.startX + animRoot.detourX) / 2
      controlY: animRoot.toBottom
        ? Math.min(animRoot.startY, animRoot.detourY) + animRoot.screenH * 0.05
        : Math.max(animRoot.startY, animRoot.detourY) - animRoot.screenH * 0.05
    }
    // leg 2: the change of course — a sweep across the opposite side
    PathQuad {
      x: animRoot.wanderX
      y: animRoot.wanderY
      controlX: (animRoot.detourX + animRoot.wanderX) / 2
        + (animRoot.toRight ? animRoot.screenW * 0.04 : -animRoot.screenW * 0.04)
      controlY: animRoot.toBottom
        ? Math.max(animRoot.detourY, animRoot.wanderY) + animRoot.screenH * 0.04
        : Math.min(animRoot.detourY, animRoot.wanderY) - animRoot.screenH * 0.04
    }
    // leg 3: into the grip's corner
    PathQuad {
      x: animRoot.mouseEndX
      y: animRoot.mouseEndY
      controlX: (animRoot.wanderX + animRoot.mouseEndX) / 2
      controlY: animRoot.toBottom
        ? Math.max(animRoot.wanderY, animRoot.mouseEndY) + animRoot.screenH * 0.05
        : Math.min(animRoot.wanderY, animRoot.mouseEndY) - animRoot.screenH * 0.05
    }
  }

  property real jumpStartX: 0
  property real jumpStartY: 0

  Path {
    id: jumpPath
    startX: animRoot.jumpStartX
    startY: animRoot.jumpStartY
    PathQuad {
      x: animRoot.landX
      y: animRoot.landY
      controlX: (animRoot.jumpStartX + animRoot.landX) / 2
      controlY: Math.min(animRoot.jumpStartY, animRoot.landY) - animRoot.screenH * 0.11
    }
  }

  PathInterpolator {
    id: mouseIp
    path: runPath
    progress: 0
  }

  // The cat trails the mouse by 16 % of the path; during the jump it holds
  // its last on-path pose in catRunIp while jumpIp carries it.
  readonly property real catRunProgress: jumpPhase
    ? 1.0
    : Math.max(0, Math.min(1, mouseIp.progress - 0.16))

  PathInterpolator {
    id: catRunIp
    path: runPath
    progress: animRoot.catRunProgress
  }

  PathInterpolator {
    id: jumpIp
    path: jumpPath
    progress: 0
  }

  // ---------------------------------------------------------------- actors
  // Side-view silhouettes facing the run direction; xScale mirrors them for
  // the mirrored corner. Positions are plain ternary bindings on the jump
  // phase, so rebinds never fight explicit assignments.
  Item {
    id: mouseItem
    readonly property real faceRight: animRoot.toRight
    x: mouseIp.x - width / 2
    y: mouseIp.y - height / 2
    width: 30
    height: 22
    transform: Scale {
      xScale: mouseItem.faceRight ? 1 : -1
      origin.x: mouseItem.width / 2
      origin.y: mouseItem.height / 2
    }

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      // body: a small teardrop
      ShapePath {
        strokeColor: "transparent"
        fillColor: animRoot.mouseColor
        PathMove { x: 4; y: 17 }
        PathCubic { control1X: 2; control1Y: 8; control2X: 8; control2Y: 4; x: 17; y: 5 }
        PathCubic { control1X: 26; control1Y: 6; control2X: 29; control2Y: 11; x: 29; y: 15 }
        PathLine { x: 19; y: 18 }
        PathLine { x: 4; y: 17 }
      }
      // head bump
      ShapePath {
        strokeColor: "transparent"
        fillColor: animRoot.mouseColor
        PathAngleArc {
          centerX: 22
          centerY: 13
          radiusX: 7
          radiusY: 6
          startAngle: 0
          sweepAngle: 360
        }
      }
      // ear
      ShapePath {
        strokeColor: "transparent"
        fillColor: animRoot.mouseColor
        PathMove { x: 17; y: 5 }
        PathLine { x: 21; y: -2 }
        PathLine { x: 24; y: 4 }
        PathLine { x: 17; y: 5 }
      }
      // tail: a thin flick behind
      ShapePath {
        strokeColor: animRoot.mouseColor
        fillColor: "transparent"
        strokeStyle: ShapePath.SolidLine
        strokeWidth: 2.2
        capStyle: ShapePath.RoundCap
        PathMove { x: 4; y: 16 }
        PathCubic { control1X: -3; control1Y: 18; control2X: -4; control2Y: 12; x: 1; y: 11 }
      }
      // legs: two little dashes under the body
      ShapePath {
        strokeColor: animRoot.mouseColor
        fillColor: "transparent"
        strokeStyle: ShapePath.SolidLine
        strokeWidth: 2.2
        capStyle: ShapePath.RoundCap
        PathMove { x: 9; y: 17 }
        PathLine { x: 8; y: 21 }
        PathMove { x: 20; y: 18 }
        PathLine { x: 21; y: 21 }
      }
    }
  }

  Item {
    id: catItem
    width: 64
    height: 52
    x: jumpPhase ? jumpIp.x - width / 2 : catRunIp.x - width / 2
    y: jumpPhase ? jumpIp.y - height / 2 : catRunIp.y - height / 2
    readonly property real faceRight: animRoot.toRight
    transform: Scale {
      xScale: catItem.faceRight ? 1 : -1
      origin.x: catItem.width / 2
      origin.y: catItem.height / 2
    }

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      // body: a loaf leaning forward
      ShapePath {
        strokeColor: "transparent"
        fillColor: animRoot.catColor
        PathMove { x: 4; y: 42 }
        PathCubic { control1X: 2; control1Y: 28; control2X: 10; control2Y: 20; x: 24; y: 20 }
        PathCubic { control1X: 36; control1Y: 20; control2X: 44; control2Y: 25; x: 44; y: 32 }
        PathCubic { control1X: 44; control1Y: 36; control2X: 40; control2Y: 40; x: 34; y: 43 }
        PathLine { x: 4; y: 42 }
      }
      // tail curling behind
      ShapePath {
        strokeColor: animRoot.catColor
        fillColor: "transparent"
        strokeStyle: ShapePath.SolidLine
        strokeWidth: 5
        capStyle: ShapePath.RoundCap
        PathMove { x: 6; y: 40 }
        PathCubic { control1X: -6; control1Y: 44; control2X: -8; control2Y: 30; x: 3; y: 30 }
      }
      // head
      ShapePath {
        strokeColor: "transparent"
        fillColor: animRoot.catColor
        PathAngleArc {
          centerX: 47
          centerY: 20
          radiusX: 13
          radiusY: 13
          startAngle: 0
          sweepAngle: 360
        }
      }
      // ears: two triangles on the head
      ShapePath {
        strokeColor: "transparent"
        fillColor: animRoot.catColor
        PathMove { x: 39; y: 11 }
        PathLine { x: 38; y: 1 }
        PathLine { x: 46; y: 8 }
        PathLine { x: 39; y: 11 }
      }
      ShapePath {
        strokeColor: "transparent"
        fillColor: animRoot.catColor
        PathMove { x: 50; y: 8 }
        PathLine { x: 55; y: 0 }
        PathLine { x: 59; y: 9 }
        PathLine { x: 50; y: 8 }
      }
      // eye and nose
      ShapePath {
        strokeColor: "transparent"
        fillColor: "#1a140c"
        PathAngleArc {
          centerX: 52
          centerY: 18
          radiusX: 2.4
          radiusY: 2.4
          startAngle: 0
          sweepAngle: 360
        }
      }
      ShapePath {
        strokeColor: "transparent"
        fillColor: "#1a140c"
        PathAngleArc {
          centerX: 60
          centerY: 23
          radiusX: 1.8
          radiusY: 1.8
          startAngle: 0
          sweepAngle: 360
        }
      }
      // front paw reaching forward
      ShapePath {
        strokeColor: animRoot.catColor
        fillColor: "transparent"
        strokeStyle: ShapePath.SolidLine
        strokeWidth: 5
        capStyle: ShapePath.RoundCap
        PathMove { x: 40; y: 40 }
        PathLine { x: 52; y: 47 }
      }
    }
  }
}
