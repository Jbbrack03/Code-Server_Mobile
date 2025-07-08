# Mobile Terminal UI/UX Design Guide

## Visual Design Principles
- **Clarity**: High contrast, readable text
- **Efficiency**: Common actions within thumb reach
- **Familiarity**: Native iOS patterns
- **Focus**: Terminal content is primary

## Screen Layouts

### Main Terminal View
```
┌─────────────────────────┐
│ Status Bar (iOS)        │
├─────────────────────────┤
│ Terminal 1 ▼  [+] [⚙️] │  ← Terminal switcher
├─────────────────────────┤
│                         │
│                         │
│    Terminal Output      │
│                         │
│                         │
│                         │
├─────────────────────────┤
│ [ls] [pwd] [git status] │  ← Custom shortcuts
├─────────────────────────┤
│ [|] [>] [<] [&] [~] [/]│  ← Special chars
├─────────────────────────┤
│      iOS Keyboard       │
└─────────────────────────┘
```

### Terminal Switcher View
```
┌─────────────────────────┐
│ Active Terminals        │
├─────────────────────────┤
│ ● Terminal 1 - ~/project│
│ ○ Terminal 2 - npm run  │
│ ○ Terminal 3 - git      │
│ ○ Terminal 4 - ssh srv  │
└─────────────────────────┘
```

### Command Shortcut Editor
```
┌─────────────────────────┐
│ Edit Shortcut      [✓]  │
├─────────────────────────┤
│ Label: [git status    ] │
│ Command: [git status  ] │
│                         │
│ Position: [3]           │
│                         │
│ [Delete]                │
└─────────────────────────┘
```

### Gesture Map
- **Pinch**: Zoom in/out (text size)
- **Tap**: Position cursor
- **Long Press**: Text selection start
- **Long Press on Shortcut**: Edit shortcut
- **Swipe Down**: Dismiss keyboard
- **Swipe Left/Right**: Switch between terminals
- **Pull Down**: Refresh terminal list
- **Tap Terminal Dropdown**: Show terminal switcher
- **3D Touch/Long Press on Status**: Settings

## Color Scheme (Dark Mode)
```
Background:     #0C0C0C (Near black)
Text:          #E0E0E0 (Light gray)
Cursor:        #00FF00 (Classic green)
Selection:     #0080FF40 (Blue with transparency)
Status Bar:    #1A1A1A (Dark gray)
Keyboard Bar:  #2A2A2A (Medium gray)
```

## Typography
- **Font**: SF Mono (System monospace)
- **Default Size**: 14pt
- **Zoom Range**: 10pt - 24pt
- **Line Height**: 1.2x

## Interaction Details

### Text Selection
1. Long press initiates selection
2. Magnifying glass appears
3. Drag handles for adjustment
4. Native iOS copy menu

### Keyboard Accessory Bar
```
┌────┬────┬────┬────┬────┬────┬────────┐
│ |  │ >  │ <  │ &  │ ~  │ /  │  Tab   │
└────┴────┴────┴────┴────┴────┴────────┘
```
- Frequently used characters
- Tap to insert
- Hold for variations (e.g., | → ||)

### Connection States
```
● Connected       (Green dot)
◐ Connecting...   (Pulsing yellow)
○ Disconnected    (Red dot)
```

## Animations
- **Connection Change**: Subtle fade transition
- **Keyboard Appearance**: Slide with spring damping
- **Text Selection**: Smooth handle movement
- **Zoom**: Real-time pinch response

## Accessibility
- **VoiceOver**: Full support for output reading
- **Dynamic Type**: Respects system text size
- **Reduce Motion**: Simplified animations
- **High Contrast**: Optional mode

## Error States

### Connection Error
```
┌─────────────────────────┐
│                         │
│    ⚠️ Connection Lost    │
│                         │
│ Unable to reach server  │
│                         │
│   [Retry]  [Settings]   │
│                         │
└─────────────────────────┘
```

### Loading State
```
┌─────────────────────────┐
│                         │
│                         │
│    Connecting to        │
│    Code-Server...       │
│                         │
│         ◐               │
│                         │
└─────────────────────────┘
```

## Mobile-Specific Optimizations

### Thumb Zones
- **Easy Reach**: Keyboard bar, bottom 40% for actions
- **Medium Reach**: Middle 40% for content
- **Hard Reach**: Top 20% for status only

### Landscape Mode (Future)
- Keyboard takes 40% width
- Terminal uses remaining 60%
- Side-by-side layout

## Performance Considerations
- **Smooth Scrolling**: 60fps target
- **Text Rendering**: Hardware acceleration
- **Memory**: Limit buffer to 1000 lines
- **Battery**: Reduce updates when backgrounded

## Implementation Notes
1. Use SwiftUI for modern iOS feel
2. Leverage native iOS text selection
3. Implement haptic feedback for actions
4. Cache rendered text for performance