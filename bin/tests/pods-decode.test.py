#!/usr/bin/env python3
"""Decoder tests for macifier-pods, against frames captured off real radio.

The interesting cases here are not the happy path — they are the Apple
advertisements that are *not* proximity-pairing frames but look enough like one
to decode into a confident, wrong answer. Every hex string below was captured
from live traffic while building this, which is also how the bug these tests
pin was found in the first place.

    python3 bin/tests/pods-decode.test.py
"""

import os
import sys
import importlib.util
from importlib.machinery import SourceFileLoader

# The daemon is `macifier-pods`, with no .py and a hyphen, because it is a
# command before it is a module. Loading it therefore needs an explicit source
# loader rather than a plain import.
HERE = os.path.dirname(os.path.abspath(__file__))
loader = SourceFileLoader("macifier_pods", os.path.join(HERE, "..", "macifier-pods"))
spec = importlib.util.spec_from_loader(loader.name, loader)
pods = importlib.util.module_from_spec(spec)
loader.exec_module(pods)

Advert = pods.Advert

failures = []


def check(name, condition, detail=""):
    if condition:
        print("  ok   " + name)
    else:
        failures.append(name)
        print("  FAIL " + name + ("\n       " + detail if detail else ""))


def parse(hexstr, rssi=-50):
    return Advert.parse("AA:BB:CC:DD:EE:FF", rssi, bytes.fromhex(hexstr))


print("macifier-pods decoder")

# A genuine frame, captured from a real pair of AirPods 4 that were on a call.
# 07 19 01 | 1920 | 02 | f9 | 8f | 11 | 00 | 06 | <16 bytes encrypted>
REAL = "071901192002f98f1100062c6fcda335ddcd6d1677eb595304d1e2"

a = parse(REAL)
check("a real frame decodes", a is not None)
if a:
    check("model id is read big-endian", a.model_id == 0x1920,
          "got 0x%04X, wanted 0x1920" % a.model_id)
    check("a known model gets a name", a.model == "AirPods 4", repr(a.model))
    check("nibble 0xF reads as unknown, not 150%",
          a.left_battery is None or a.right_battery is None)
    check("the reported bud battery is 90%",
          90 in (a.left_battery, a.right_battery),
          "got %r/%r" % (a.left_battery, a.right_battery))
    check("connection state is carried through", a.conn_state == pods.ST_CALL)
    check("being on a call counts as busy", a.conn_state in pods.BUSY)

# The bug this file exists for. Apple sends several TLV types in the same
# manufacturer field; these two begin with 0x07 but are not proximity pairing,
# and before the length and sanity checks they decoded into confident nonsense
# (a 120% battery, a connection state of 0x7D).
check("a short frame claiming type 0x07 is rejected",
      parse("07190119") is None)
check("type 0x07 with the wrong TLV length is rejected",
      parse("070c01192002f98f110006aabbccddeeff0011223344556677") is None)
check("an impossible battery nibble is rejected",
      parse("071901192002cb8f1100062c6fcda335ddcd6d1677eb595304d1e2") is None,
      "0xCB is 12 and 11 tens of percent; neither exists")
check("an unheard-of connection state is rejected",
      parse("071901192002f98f11007d2c6fcda335ddcd6d1677eb595304d1e2") is None,
      "0x7D is not a connection state")

# Other real Apple message types seen in the same capture. None is ours.
for name, frame in (
    ("nearby-info 0x10", "10052998dff03a"),
    ("0x12 handoff-ish", "12020001"),
    ("find-my 0x12/0x19", "12193937b0d7360b98ef04b91f350926df0c78a48ca8b0754f0211"),
    ("0x01 all-zero", "0100000000000000000000000080000000"),
):
    check("%s is not mistaken for AirPods" % name, parse(frame) is None)

# Pairing-mode frames restructure the fields, so they must not be read as
# status frames even though the type and length are right.
check("a pairing-mode frame is skipped",
      parse("071900192002f98f1100062c6fcda335ddcd6d1677eb595304d1e2") is None)

# An unrecognised model must still work. MODELS will always lag Apple, and
# refusing new hardware is worse than not knowing its marketing name.
b = parse("071901272002777f1100052c6fcda335ddcd6d1677eb595304d1e2")
check("an unknown model id still decodes", b is not None)
if b:
    check("an unknown model has no name but keeps its id",
          b.model is None and b.model_id == 0x2720,
          "model=%r id=0x%04X" % (b.model, b.model_id))
    check("an unknown model still reports battery",
          b.left_battery == 70 and b.right_battery == 70,
          "got %r/%r" % (b.left_battery, b.right_battery))
    check("describe() falls back to the raw id",
          "0x2720" in b.describe(), b.describe())

# The lid bit is only meaningful while the reporting bud is in the case, which
# is what stops "lid closed" being asserted about buds in someone's ears.
in_ear = parse(REAL)
check("lid state is not claimed for a bud outside the case",
      in_ear is not None and in_ear.lid_state is None)


# --- model identification ----------------------------------------------------
# BlueZ's Modalias holds the product id as the device reported it; the
# advertisement carries the same id byte-swapped, which is why every entry in
# MODELS ends in 0x20. Confirmed against real hardware: a pair whose Modalias
# reads p2027 advertises as 0x2720.
class FakePods(pods.Pods):
    def __init__(self, modalias):
        self._modalias = modalias
        self.target = "/fake"
        self.target_model_id = None
        self.threshold = -65
        self.triggers = {"lid", "inear"}
        self.lid_counters = {}
        self.in_ear = {}

    def device_prop(self, path, name, default=None):
        return self._modalias if name == "Modalias" else default


check("Modalias product id is byte-swapped into an advert model id",
      FakePods("bluetooth:v004Cp2027d0429").model_from_modalias() == 0x2720,
      "got %r" % FakePods("bluetooth:v004Cp2027d0429").model_from_modalias())
check("a known model round-trips through Modalias",
      FakePods("bluetooth:v004Cp2019d0429").model_from_modalias() == 0x1920)
check("a non-Apple vendor is not claimed",
      FakePods("bluetooth:v05ACp2027d0429").model_from_modalias() is None)

# The trailing dNNNN is a device version and it is not stable: the same pair
# read d0001 shortly after pairing and d0429 once BlueZ had the full DID
# record. Nothing may depend on it, so prove the parser ignores it rather than
# leaving that as a comment.
check("the volatile device-version field is ignored",
      FakePods("bluetooth:v004Cp2027d0001").model_from_modalias()
      == FakePods("bluetooth:v004Cp2027d9999").model_from_modalias()
      == 0x2720)
check("a Modalias with no version field at all still parses",
      FakePods("bluetooth:v004Cp2027").model_from_modalias() == 0x2720)
check("a missing Modalias is not fatal",
      FakePods(None).model_from_modalias() is None)
check("an unparseable Modalias is not fatal",
      FakePods("usb:v1D6Bp0246").model_from_modalias() is None)

# --- triggers are transitions, not levels ------------------------------------
# The bug this pins: on the first advertisement there is nothing to compare
# against. Reading that as a transition means buds already in your ears look as
# though they just went in, so merely starting the daemon would take audio off
# your phone.
IN_EAR = "071901272002777f1100052c6fcda335ddcd6d1677eb595304d1e2"

p = FakePods(None)
first = p.reached_for(parse(IN_EAR))
check("a bud already in an ear is not a reason on the first sighting",
      first == [], "got %r" % first)
check("the same bud, still in, is still not a reason",
      p.reached_for(parse(IN_EAR)) == [])

# Out, then back in, is a transition we actually observed.
OUT_OF_EAR = "071901272000777f1100052c6fcda335ddcd6d1677eb595304d1e2"
p2 = FakePods(None)
p2.reached_for(parse(IN_EAR))          # first sighting, in ear
p2.reached_for(parse(OUT_OF_EAR))      # taken out
again = p2.reached_for(parse(IN_EAR))  # put back
check("taking a bud out and putting it back is a reason",
      "bud in ear" in again, "got %r" % again)

# Same rule for the lid: a case that has been open for an hour is not a request.
LID_OPEN_1 = "071901272042777f1000042c6fcda335ddcd6d1677eb595304d1e2"
LID_OPEN_2 = "071901272042777f1100042c6fcda335ddcd6d1677eb595304d1e2"
p3 = FakePods(None)
lid_first = p3.reached_for(parse(LID_OPEN_1))
check("an already-open lid is not a reason on the first sighting",
      "lid opened" not in lid_first, "got %r" % lid_first)
opened = p3.reached_for(parse(LID_OPEN_2))
check("the lid-open counter advancing is a reason",
      "lid opened" in opened, "got %r" % opened)

print("\n%s" % ("all checks passed" if not failures
                else "%d failed: %s" % (len(failures), ", ".join(failures))))
sys.exit(1 if failures else 0)
