//
//  vRFBConvertKey.swift
//  VNCTest
//
//  Created by zimsneexh on 07.06.23.
//

import Foundation
import AppKit

struct MacOSKeyEvent {
    var char: Character?;
    var modifier_flag: NSEvent.ModifierFlags?;
    var keycode: UInt32;

    init(char: String, modifier_flag: NSEvent.ModifierFlags? = nil, keycode: UInt32) {
        // Handle no character
        if char.isEmpty {
            self.char = nil;
        } else {
            self.char = Character(char)
        }

        self.modifier_flag = modifier_flag
        self.keycode = keycode
    }
}

// MARK: Probably needs some changes to support other layouts, aswell.
var XKeyToMac: [UInt32:MacOSKeyEvent] = [
    /// Keys without Shift modifier
    0x0afc: MacOSKeyEvent(char: "^", keycode: 10),
    0x0031: MacOSKeyEvent(char: "1", keycode: 18),
    0x0032: MacOSKeyEvent(char: "2", keycode: 19),
    0x0033: MacOSKeyEvent(char: "3", keycode: 20),
    0x0034: MacOSKeyEvent(char: "4", keycode: 21),
    0x0035: MacOSKeyEvent(char: "5", keycode: 23),
    0x0036: MacOSKeyEvent(char: "6", keycode: 22),
    0x0037: MacOSKeyEvent(char: "7", keycode: 26),
    0x0038: MacOSKeyEvent(char: "8", keycode: 28),
    0x0039: MacOSKeyEvent(char: "9", keycode: 25),
    0x0030: MacOSKeyEvent(char: "0", keycode: 29),
    0x00df: MacOSKeyEvent(char: "ß", keycode: 27),
    0x00b4: MacOSKeyEvent(char: "´", keycode: 24),
    0xff09: MacOSKeyEvent(char: "",  keycode: 48),
    0xff08: MacOSKeyEvent(char: "",  keycode: 51), // Enter
    0x0020: MacOSKeyEvent(char: "",  keycode: 49), // Space
    0xffe1: MacOSKeyEvent(char: "",  keycode: 56), // Shift
    0xff1b: MacOSKeyEvent(char: "",  keycode: 53), // ESC
    0x0071: MacOSKeyEvent(char: "q", keycode: 12),
    0x0077: MacOSKeyEvent(char: "w", keycode: 13),
    0x0065: MacOSKeyEvent(char: "e", keycode: 14),
    0x0072: MacOSKeyEvent(char: "r", keycode: 15),
    0x0074: MacOSKeyEvent(char: "t", keycode: 17),
    0x007a: MacOSKeyEvent(char: "z", keycode: 16),
    0x0075: MacOSKeyEvent(char: "u", keycode: 32),
    0x0069: MacOSKeyEvent(char: "i", keycode: 34),
    0x006f: MacOSKeyEvent(char: "o", keycode: 31),
    0x0070: MacOSKeyEvent(char: "p", keycode: 35),
    0x00fc: MacOSKeyEvent(char: "ü", keycode: 33),
    0x002b: MacOSKeyEvent(char: "+", keycode: 30),
    0xff0d: MacOSKeyEvent(char: "", keycode: 36),
    0x0061: MacOSKeyEvent(char: "a", keycode: 0),
    0x0073: MacOSKeyEvent(char: "s", keycode: 1),
    0x0064: MacOSKeyEvent(char: "d", keycode: 2),
    0x0066: MacOSKeyEvent(char: "f", keycode: 3),
    0x0067: MacOSKeyEvent(char: "g", keycode: 5),
    0x0068: MacOSKeyEvent(char: "h", keycode: 4),
    0x006a: MacOSKeyEvent(char: "j", keycode: 38),
    0x006b: MacOSKeyEvent(char: "k", keycode: 40),
    0x006c: MacOSKeyEvent(char: "l", keycode: 37),
    0x00f6: MacOSKeyEvent(char: "ö", keycode: 41),
    0x00e4: MacOSKeyEvent(char: "ä", keycode: 39),
    0x0023: MacOSKeyEvent(char: "#", keycode: 42),
    0x003c: MacOSKeyEvent(char: "<", keycode: 50),
    0x0079: MacOSKeyEvent(char: "y", keycode: 6),
    0x0078: MacOSKeyEvent(char: "x", keycode: 7),
    0x0063: MacOSKeyEvent(char: "c", keycode: 8),
    0x0076: MacOSKeyEvent(char: "v", keycode: 9),
    0x0062: MacOSKeyEvent(char: "b", keycode: 11),
    0x006e: MacOSKeyEvent(char: "n", keycode: 45),
    0x006d: MacOSKeyEvent(char: "m", keycode: 46),
    0x002c: MacOSKeyEvent(char: ",", keycode: 43),
    0x002e: MacOSKeyEvent(char: ".", keycode: 47),
    0x002d: MacOSKeyEvent(char: "-", keycode: 44),
    0xff51: MacOSKeyEvent(char: "", keycode: 123),
    0xff52: MacOSKeyEvent(char: "", keycode: 126),
    0xff54: MacOSKeyEvent(char: "", keycode: 125),
    0xff53: MacOSKeyEvent(char: "", keycode: 124),

    /// Keys with Shift modifier
    0x00b0: MacOSKeyEvent(char: "°", modifier_flag: .shift, keycode: 10),
    0x0021: MacOSKeyEvent(char: "!", modifier_flag: .shift, keycode: 18),
    0x0022: MacOSKeyEvent(char: "\"", modifier_flag: .shift, keycode: 19),
    0x00a7: MacOSKeyEvent(char: "§", modifier_flag: .shift, keycode: 20),
    0x0024: MacOSKeyEvent(char: "$", modifier_flag: .shift, keycode: 21),
    0x0025: MacOSKeyEvent(char: "%", modifier_flag: .shift, keycode: 23),
    0x0026: MacOSKeyEvent(char: "&", modifier_flag: .shift, keycode: 22),
    0x002f: MacOSKeyEvent(char: "/", modifier_flag: .shift, keycode: 26),
    0x0028: MacOSKeyEvent(char: "(", modifier_flag: .shift, keycode: 28),
    0x0029: MacOSKeyEvent(char: ")", modifier_flag: .shift, keycode: 25),
    0x003d: MacOSKeyEvent(char: "=", modifier_flag: .shift, keycode: 29),
    0x003f: MacOSKeyEvent(char: "?", modifier_flag: .shift, keycode: 27),
    0xfe50: MacOSKeyEvent(char: "`", modifier_flag: .shift, keycode: 24),
    0x0051: MacOSKeyEvent(char: "Q", modifier_flag: .shift, keycode: 12),
    0x0057: MacOSKeyEvent(char: "W", modifier_flag: .shift, keycode: 13),
    0x0045: MacOSKeyEvent(char: "E", modifier_flag: .shift, keycode: 14),
    0x0052: MacOSKeyEvent(char: "R", modifier_flag: .shift, keycode: 15),
    0x0054: MacOSKeyEvent(char: "T", modifier_flag: .shift, keycode: 17),
    0x005a: MacOSKeyEvent(char: "Z", modifier_flag: .shift, keycode: 16),
    0x0055: MacOSKeyEvent(char: "U", modifier_flag: .shift, keycode: 32),
    0x0049: MacOSKeyEvent(char: "I", modifier_flag: .shift, keycode: 34),
    0x004f: MacOSKeyEvent(char: "O", modifier_flag: .shift, keycode: 31),
    0x0050: MacOSKeyEvent(char: "P", modifier_flag: .shift, keycode: 35),
    0x00dc: MacOSKeyEvent(char: "Ü", modifier_flag: .shift, keycode: 33),
    0x002a: MacOSKeyEvent(char: "*", modifier_flag: .shift, keycode: 30),
    0x0041: MacOSKeyEvent(char: "A", modifier_flag: .shift, keycode: 0),
    0x0053: MacOSKeyEvent(char: "S", modifier_flag: .shift, keycode: 1),
    0x0044: MacOSKeyEvent(char: "D", modifier_flag: .shift, keycode: 2),
    0x0046: MacOSKeyEvent(char: "F", modifier_flag: .shift, keycode: 3),
    0x0047: MacOSKeyEvent(char: "G", modifier_flag: .shift, keycode: 5),
    0x0048: MacOSKeyEvent(char: "H", modifier_flag: .shift, keycode: 4),
    0x004a: MacOSKeyEvent(char: "J", modifier_flag: .shift, keycode: 38),
    0x004b: MacOSKeyEvent(char: "K", modifier_flag: .shift, keycode: 40),
    0x004c: MacOSKeyEvent(char: "L", modifier_flag: .shift, keycode: 37),
    0x00d6: MacOSKeyEvent(char: "Ö", modifier_flag: .shift, keycode: 41),
    0x00c4: MacOSKeyEvent(char: "Ä", modifier_flag: .shift, keycode: 39),
    0x0027: MacOSKeyEvent(char: "'", modifier_flag: .shift, keycode: 42),
    0x003e: MacOSKeyEvent(char: ">", modifier_flag: .shift, keycode: 50),
    0x0059: MacOSKeyEvent(char: "Y", modifier_flag: .shift, keycode: 6),
    0x0058: MacOSKeyEvent(char: "X", modifier_flag: .shift, keycode: 7),
    0x0043: MacOSKeyEvent(char: "C", modifier_flag: .shift, keycode: 8),
    0x0056: MacOSKeyEvent(char: "V", modifier_flag: .shift, keycode: 9),
    0x0042: MacOSKeyEvent(char: "B", modifier_flag: .shift, keycode: 11),
    0x004e: MacOSKeyEvent(char: "N", modifier_flag: .shift, keycode: 45),
    0x004d: MacOSKeyEvent(char: "M", modifier_flag: .shift, keycode: 46),
    0x003b: MacOSKeyEvent(char: ";", modifier_flag: .shift, keycode: 43),
    0x003a: MacOSKeyEvent(char: ":", modifier_flag: .shift, keycode: 47),
    0x005f: MacOSKeyEvent(char: "_", modifier_flag: .shift, keycode: 44),

    /// Function keys
    0xffbe: MacOSKeyEvent(char: "", keycode: 122), // F1
    0xffbf: MacOSKeyEvent(char: "", keycode: 120), // F2
    0xffc0: MacOSKeyEvent(char: "", keycode: 99),  // F3
    0xffc1: MacOSKeyEvent(char: "", keycode: 118), // F4
    0xffc2: MacOSKeyEvent(char: "", keycode: 96),  // F5
    0xffc3: MacOSKeyEvent(char: "", keycode: 97),  // F6
    0xffc4: MacOSKeyEvent(char: "", keycode: 98),  // F7
    0xffc5: MacOSKeyEvent(char: "", keycode: 100), // F8
    0xffc6: MacOSKeyEvent(char: "", keycode: 101), // F9
    0xffc7: MacOSKeyEvent(char: "", keycode: 109), // F10
    0xffc8: MacOSKeyEvent(char: "", keycode: 103), // F11
    0xffc9: MacOSKeyEvent(char: "", keycode: 111), // F12
    0xffca: MacOSKeyEvent(char: "", keycode: 105), // F13
    0xffcb: MacOSKeyEvent(char: "", keycode: 107), // F14
    0xffcc: MacOSKeyEvent(char: "", keycode: 113), // F15
]

func convertXKeySymToKeyCode(XKeySym: UInt32) -> MacOSKeyEvent? {
    VTrace("Converting Key Event..")
    if let key_code = XKeyToMac[XKeySym] {
        VTrace("[KeySym] \(XKeySym) => \(key_code.keycode) with modifier \(String(describing: key_code.modifier_flag))")
        return key_code;
    } else {
        VWarn("[KeySym] Ignoring unknown XKeySym: \(XKeySym)")
        return nil;
    }
}
