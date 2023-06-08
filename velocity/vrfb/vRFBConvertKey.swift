//
//  vRFBConvertKey.swift
//  VNCTest
//
//  Created by zimsneexh on 07.06.23.
//

import Foundation

var XKeyMap: [UInt32: UInt32] = [
// Special Keys
0xff08: 51,  // Backspace
0xff09: 48,  // Tab
0xff0d: 36,  // Enter
0xff1b: 53,  // ESC
0xffff: 117, // Delete
0xff50: 115, // Home
0xff57: 119, // End
0xff55: 116, // Page UP
0xff56: 121, // Page DOWN
0xff51: 123, // Left
0xff52: 126, // Up
0xff53: 124, // Right,
0xff54: 125, // Down,
0xffbe: 122, // F1,
0xffbf: 120, // F2,
0xffc0: 99,  // F3,
0xffc1: 118, // F4,
0xffc2: 96,  // F5,
0xffc3: 97,  // F6,
0xffc4: 98,  // F7,
0xffc5: 100, // F8,
0xffc6: 101, // F9,
0xffc7: 109, // F10,
0xffc8: 103, // F11,
0xffc9: 111, // F12,
0xffca: 105, // F13,
0xffcb: 107, // F14,
0xffcc: 113, // F15,
0xffe1: 56,  // shift_l,
0xffe2: 56,  // shift_r,
0xffe3: 59,  // ctrl_l,
0xffe4: 59,  // ctrl_r,
0xffe7: 55,  // Meta Key
0xffe8: 55,  // Meta key
0xffe9: 58,  // alt,
0xffea: 58,  // alt_gr, -> mapped to Alt
0xff14: 107, // "Scroll Lock, but should be F14
0xff15: 105, // "Print Screen" but should be F13
0xff7f: 71,  // Num Lock
0xffe5: 57,  // keyboard.Key.caps_lock,
0xff13: 113, // "Pause" but should be F15
0xffeb: 55,  // Super key
0xffec: 55,  // Super key
0x002f: 44,  // Forward Slash
0x005c: 42,  // Back Slash
0x0020: 49,  // Space
0xff7e: 58,  // Alt_gr
0xfe03: 55,  // Meta Key,

// Characters
0x07e: 50, // Tilde
0x031: 18, // 1
0x032: 19, // 2
0x033: 20, // 3
0x034: 21, // 4
0x035: 23, // 5
0x036: 22, // 6
0x037: 26, // 7
0x038: 28, // 8
0x039: 25, // 9
0x030: 29, // 0
0x02d: 27, // -
0x03d: 24, // =
0x041: 0,  // a
0x042: 11, // b
0x043: 8,  // c
0x044: 2,  // d
0x045: 14, // e
0x046: 3,  // f
0x047: 5,  // g
0x048: 4,  // h
0x049: 34, // i
0x04a: 38, // j
0x04b: 40, // k
0x04c: 37, // l
0x04d: 45, // m
0x04e: 46, // n
0x04f: 31, // o
0x050: 35, // p
0x051: 12, // q
0x052: 15, // r
0x053: 1,  // s
0x054: 17, // t
0x055: 32, // u
0x056: 9,  // v
0x057: 13, // w
0x058: 7,  // x
0x059: 16, // y
0x05a: 6,  // z
0x05b: 33, // [
0x05c: 42, // \
0x05d: 30, // ]
0x07b: 33, // (
0x07d: 30, // )
0x07c: 42, // |
0x03a: 41, // :
0x03b: 39, // ;
0x027: 39, // '
0x022: 39, // '
0x03c: 43, // <
0x03e: 47, // >
0x02c: 43, // ,
0x02e: 47, // .
0x02f: 44, // /
0x03f: 44, // ?
0x020: 49, // Space

// Keypad
0xffb0: 82,
0xffb1: 83,
0xffb2: 84,
0xffb3: 85,
0xffb4: 86,
0xffb5: 87,
0xffb6: 88,
0xffb7: 89,
0xffb8: 91,
0xffb9: 92,
]

func convertXKeySymToKeyCode(XKeySym: UInt32) -> UInt32? {
    if let key_code = XKeyMap[XKeySym] {
        return key_code;
    } else {
        NSLog("Ignoring unknown key: \(XKeySym)")
        return nil;
    }
}


