// Mock data + helpers that mimic the registry model.

const HOUSE_DATA = {
  home: "MAPLE STREET",
  ownerInitial: "A",
  city: "Portland, OR",
  weather: {
    temp: 51, code: "Overcast", icon: "cloud",
    suggestion: "Cool out — a light jacket might help"
  },
  counts: { devices: 17, rooms: 6, active: 9, offline: 1 },
  scenes: [
    { id: "s1", name: "Morning",     glyph: "sun",       desc: "7 devices" },
    { id: "s2", name: "Movie",       glyph: "lightbulb", desc: "4 devices" },
    { id: "s3", name: "Goodnight",   glyph: "moon",      desc: "11 devices" },
    { id: "s4", name: "Away",        glyph: "lock",      desc: "14 devices" },
    { id: "s5", name: "Dinner",      glyph: "kitchen",   desc: "3 devices" },
  ],
  rooms: [
    { id: "r1", name: "Living Room", glyph: "sofa",    total: 5, active: 3 },
    { id: "r2", name: "Kitchen",     glyph: "kitchen", total: 4, active: 2 },
    { id: "r3", name: "Bedroom",     glyph: "bed",     total: 3, active: 1 },
    { id: "r4", name: "Den",         glyph: "sofa",    total: 2, active: 1 },
    { id: "r5", name: "Family Room", glyph: "sofa",    total: 4, active: 2 },
    { id: "r6", name: "Entryway",    glyph: "door",    total: 1, active: 0 },
  ]
};

// Devices by room id
const DEVICES = {
  r1: [
    { id: "d1", name: "Ceiling Lights",   cat: "light",    state: "ON · 82%",       on: true,  provider: "HOMEKIT", glyph: "lightbulb" },
    { id: "d2", name: "Floor Lamp",       cat: "light",    state: "ON · 40%",       on: true,  provider: "HOMEKIT", glyph: "lightbulb" },
    { id: "d3", name: "Thermostat",       cat: "thermo",   state: "68° · TGT 71°",  on: true,  provider: "NEST",    glyph: "thermo" },
    { id: "d4", name: "Sonos Beam",       cat: "speaker",  state: "PLAYING · TREATS", on: true,provider: "SONOS",   glyph: "speaker" },
    { id: "d5", name: "Front Door",       cat: "lock",     state: "LOCKED",         on: false, provider: "HOMEKIT", glyph: "lock" },
  ]
};

// Thermostat data
const THERM = {
  name: "Living Room Thermo",
  room: "Living Room",
  provider: "NEST",
  current: 68,
  target: 71,
  mode: "heat", // heat | cool | auto | off
  humidity: 42,
  outdoor: 51,
  outdoorHumidity: 73,
  range: [60, 90],
  schedule: [
    { label: "MORNING", time: "06:00", temp: 70 },
    { label: "DAY",     time: "08:00", temp: 68 },
    { label: "EVENING", time: "17:30", temp: 72 },
    { label: "NIGHT",   time: "22:00", temp: 65 },
  ]
};

// Devices in other rooms
DEVICES.r2 = [
  { id: "d6",  name: "Kitchen Lights",  cat: "light",   state: "ON · 60%",       on: true,  provider: "HOMEKIT",   glyph: "lightbulb" },
  { id: "d7",  name: "Under-Cabinet",   cat: "light",   state: "OFF",            on: false, provider: "HOMEKIT",   glyph: "lightbulb" },
  { id: "d8",  name: "Fridge",          cat: "sensor",  state: "38° · OK",       on: true,  provider: "SMARTTHINGS", glyph: "kitchen" },
  { id: "d9",  name: "Range Fan",       cat: "fan",     state: "OFF",            on: false, provider: "HOMEKIT",   glyph: "fan" },
];
DEVICES.r3 = [
  { id: "d10", name: "Bedside Lamp",    cat: "light",   state: "OFF",            on: false, provider: "HOMEKIT",   glyph: "lightbulb" },
  { id: "d11", name: "Air Purifier",    cat: "fan",     state: "AUTO · LOW",     on: true,  provider: "SMARTTHINGS", glyph: "fan" },
  { id: "d12", name: "Blinds",          cat: "shade",   state: "OPEN · 70%",     on: true,  provider: "HOMEKIT",   glyph: "door" },
];
DEVICES.r4 = [
  { id: "d13", name: "Reading Lamp",    cat: "light",   state: "ON · 25%",       on: true,  provider: "HOMEKIT",   glyph: "lightbulb" },
  { id: "d14", name: "Desk Speaker",    cat: "speaker", state: "IDLE",           on: false, provider: "SONOS",     glyph: "speaker" },
];
DEVICES.r5 = [
  { id: "d15", name: "Overhead Lights", cat: "light",   state: "ON · 50%",       on: true,  provider: "HOMEKIT",   glyph: "lightbulb" },
  { id: "d16", name: "TV",              cat: "media",   state: "OFF",            on: false, provider: "HOMEKIT",   glyph: "speaker" },
  { id: "d17", name: "Camera",          cat: "camera",  state: "RECORDING",      on: true,  provider: "HOMEKIT",   glyph: "camera" },
  { id: "d18", name: "Sonos Arc",       cat: "speaker", state: "PLAYING",        on: true,  provider: "SONOS",     glyph: "speaker" },
];
DEVICES.r6 = [
  { id: "d19", name: "Front Door Lock", cat: "lock",    state: "LOCKED",         on: false, provider: "HOMEKIT",   glyph: "lock" },
];

// Flat list across rooms (for Devices tab)
const ALL_DEVICES = [
  ...DEVICES.r1.map(d => ({ ...d, room: "Living Room", roomId: "r1" })),
  ...DEVICES.r2.map(d => ({ ...d, room: "Kitchen",     roomId: "r2" })),
  ...DEVICES.r3.map(d => ({ ...d, room: "Bedroom",     roomId: "r3" })),
  ...DEVICES.r4.map(d => ({ ...d, room: "Den",         roomId: "r4" })),
  ...DEVICES.r5.map(d => ({ ...d, room: "Family Room", roomId: "r5" })),
  ...DEVICES.r6.map(d => ({ ...d, room: "Entryway",    roomId: "r6" })),
];

// Activity log
const ACTIVITY = [
  { id: "a1", time: "09:38", label: "Thermostat target 71°", sub: "You · Living Room",    glyph: "thermo" },
  { id: "a2", time: "09:22", label: "Ceiling Lights on",     sub: "Scene: Morning",       glyph: "lightbulb" },
  { id: "a3", time: "08:14", label: "Front Door unlocked",   sub: "Alex · HomeKit",       glyph: "lock" },
  { id: "a4", time: "07:00", label: "Scene Morning ran",     sub: "7 devices changed",    glyph: "sun" },
  { id: "a5", time: "06:45", label: "Camera recorded motion",sub: "Family Room · 8s",     glyph: "camera" },
  { id: "a6", time: "23:04", label: "Goodnight scene ran",   sub: "11 devices changed",   glyph: "moon" },
  { id: "a7", time: "22:11", label: "Bedside Lamp off",      sub: "You · Bedroom",        glyph: "lightbulb" },
];

// Energy — hourly draw for today, in kWh per hour
const ENERGY = {
  today: 14.2,       // total today, kWh
  yesterday: 16.8,
  month: 312,
  hourly: [0.4,0.3,0.3,0.3,0.3,0.4,0.9,1.2,0.8,0.6,0.5,0.5,0.7,0.6,0.5,0.6,0.9,1.3,1.4,1.2,0.9,0.7,0.5,0.4],
  byCategory: [
    { label: "Climate",   kwh: 7.2, pct: 0.51 },
    { label: "Lighting",  kwh: 3.1, pct: 0.22 },
    { label: "Media",     kwh: 2.4, pct: 0.17 },
    { label: "Other",     kwh: 1.5, pct: 0.10 },
  ],
};

window.HOUSE_DATA = HOUSE_DATA;
window.DEVICES = DEVICES;
window.ALL_DEVICES = ALL_DEVICES;
window.ACTIVITY = ACTIVITY;
window.ENERGY = ENERGY;
window.THERM = THERM;
