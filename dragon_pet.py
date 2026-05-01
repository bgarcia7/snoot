#!/usr/bin/env python3
"""A tiny macOS desktop dragon pet.

Run with:
    python3 dragon_pet.py

Controls:
    left click        pet the dragon
    drag              move the dragon
    double click      feed the dragon
    right/control click menu
    Esc or q          quit
"""

from __future__ import annotations

import math
import os
import random
import shutil
import subprocess
import time
import tkinter as tk


class DragonPet:
    WIN_W = 260
    WIN_H = 250
    FRAME_MS = 33

    BODY = "#67d8f4"
    BODY_DARK = "#249fc9"
    BODY_LIGHT = "#a8f0ff"
    BELLY = "#ffdc75"
    WING = "#43c2e7"
    WING_LIGHT = "#83e4ff"
    SCARF = "#ff6670"
    INK = "#4b3a3f"

    def __init__(self) -> None:
        self.root = tk.Tk()
        self.root.title("Pocket Dragon")
        self.root.overrideredirect(True)
        self.root.resizable(False, False)

        self.bg = self._configure_window()
        try:
            self.canvas = self._make_canvas(self.bg)
        except tk.TclError:
            self.bg = "#06131b"
            self.root.configure(bg=self.bg)
            self.canvas = self._make_canvas(self.bg)
        self.canvas.pack()

        self.screen_w = self.root.winfo_screenwidth()
        self.screen_h = self.root.winfo_screenheight()
        self.x = random.randint(30, max(31, self.screen_w - self.WIN_W - 30))
        self.y = max(70, self.screen_h - self.WIN_H - 120)
        self.vx = random.choice([-1.8, 1.8])
        self.vy = 0.0
        self.target_x = self.x
        self.target_y = self.y
        self.facing = 1 if self.vx >= 0 else -1

        self.phase = 0.0
        self.last_tick = time.time()
        self.next_decision = 0.0
        self.next_chirp = time.time() + random.uniform(12, 22)
        self.next_bounds_check = 0.0
        self.bubble_text = "hi!"
        self.bubble_until = time.time() + 3.5
        self.mouth_until = 0.0
        self.hunger = 18.0
        self.affection = 76.0
        self.dragging = False
        self.drag_offset_x = 0
        self.drag_offset_y = 0
        self.press_screen_x = 0
        self.press_screen_y = 0
        self.was_dragged = False
        self.sparkles: list[dict[str, float | str]] = []

        self.sound_on = tk.BooleanVar(value=True)
        self.voice_on = tk.BooleanVar(value=False)
        self.menu = self._build_menu()

        self._bind_events()
        self._move_window()
        self._choose_target()
        self._tick()

    def _configure_window(self) -> str:
        solid_mode = os.environ.get("DRAGON_SOLID_BG") == "1"
        bg = "#071821" if solid_mode else "systemTransparent"
        try:
            self.root.configure(bg=bg)
        except tk.TclError:
            bg = "#ff00ff" if not solid_mode else "#071821"
            self.root.configure(bg=bg)

        try:
            self.root.attributes("-topmost", True)
        except tk.TclError:
            pass

        if not solid_mode:
            try:
                self.root.attributes("-transparent", True)
            except tk.TclError:
                pass

            try:
                self.root.attributes("-transparentcolor", bg)
            except tk.TclError:
                pass

        try:
            self.root.attributes("-alpha", 0.98)
        except tk.TclError:
            pass

        return bg

    def _build_menu(self) -> tk.Menu:
        menu = tk.Menu(self.root, tearoff=False)
        menu.add_command(label="Pet the snoot", command=self.pet)
        menu.add_command(label="Feed a meteor berry", command=self.feed)
        menu.add_separator()
        menu.add_checkbutton(label="Sound chirps", variable=self.sound_on)
        menu.add_checkbutton(label="Voice chirps", variable=self.voice_on)
        menu.add_separator()
        menu.add_command(label="Quit", command=self.root.destroy)
        return menu

    def _make_canvas(self, bg: str) -> tk.Canvas:
        return tk.Canvas(
            self.root,
            width=self.WIN_W,
            height=self.WIN_H,
            bg=bg,
            highlightthickness=0,
            bd=0,
            relief="flat",
        )

    def _bind_events(self) -> None:
        self.canvas.bind("<ButtonPress-1>", self._start_drag)
        self.canvas.bind("<B1-Motion>", self._drag)
        self.canvas.bind("<ButtonRelease-1>", self._finish_drag)
        self.canvas.bind("<Double-Button-1>", self._double_click)
        self.canvas.bind("<Button-2>", self._show_menu)
        self.canvas.bind("<Button-3>", self._show_menu)
        self.canvas.bind("<Control-Button-1>", self._show_menu)
        self.root.bind("<Escape>", lambda _event: self.root.destroy())
        self.root.bind("q", lambda _event: self.root.destroy())
        self.root.bind("f", lambda _event: self.feed())
        self.root.bind("p", lambda _event: self.pet())

    def run(self) -> None:
        self.root.mainloop()

    def _tick(self) -> None:
        now = time.time()
        dt = min(0.08, max(0.001, now - self.last_tick))
        self.last_tick = now
        self.phase += dt * 7.0

        self._refresh_bounds(now)
        self._update_needs(dt)
        self._maybe_chirp(now)
        self._update_motion(now, dt)
        self._update_particles(dt)
        self._draw(now)

        self.root.after(self.FRAME_MS, self._tick)

    def _refresh_bounds(self, now: float) -> None:
        if now < self.next_bounds_check:
            return
        self.screen_w = self.root.winfo_screenwidth()
        self.screen_h = self.root.winfo_screenheight()
        self.next_bounds_check = now + 2.0

    def _update_needs(self, dt: float) -> None:
        self.hunger = min(100.0, self.hunger + dt * 1.05)
        self.affection = max(0.0, self.affection - dt * 0.35)

    def _maybe_chirp(self, now: float) -> None:
        if now < self.next_chirp:
            return

        if self.hunger > 68:
            message = random.choice(("snack pls?", "tiny snack?", "feed me?"))
        elif self.affection < 36:
            message = random.choice(("pet me pls?", "snoot pat?", "tap me!"))
        else:
            message = random.choice(("chirp chirp!", "hi hi!", "got snacks?", "pet me?"))

        self.chirp(message, seconds=5.2)
        self.next_chirp = now + random.uniform(26, 66)

    def _update_motion(self, now: float, dt: float) -> None:
        if self.dragging:
            return

        if now >= self.next_decision:
            self._choose_target()

        dx = self.target_x - self.x
        dy = self.target_y - self.y
        self.vx += max(-0.42, min(0.42, dx * 0.006))
        self.vy += max(-0.35, min(0.35, dy * 0.005))
        self.vx *= 0.90
        self.vy *= 0.90

        speed = math.hypot(self.vx, self.vy)
        max_speed = 4.0 if self.hunger < 75 else 2.8
        if speed > max_speed:
            scale = max_speed / speed
            self.vx *= scale
            self.vy *= scale

        if abs(self.vx) > 0.15:
            self.facing = 1 if self.vx > 0 else -1

        self.x += self.vx * (dt / 0.033)
        self.y += self.vy * (dt / 0.033)
        self._keep_on_screen()
        self._move_window()

    def _choose_target(self) -> None:
        left = 12
        right = max(left, self.screen_w - self.WIN_W - 12)
        top = 62
        bottom = max(top, self.screen_h - self.WIN_H - 78)

        if random.random() < 0.68:
            self.target_x = random.randint(left, right)
            self.target_y = random.randint(max(top, bottom - 85), bottom)
        else:
            self.target_x = random.randint(left, right)
            self.target_y = random.randint(top, bottom)

        self.next_decision = time.time() + random.uniform(2.5, 7.0)

    def _keep_on_screen(self) -> None:
        min_x = 8
        max_x = max(min_x, self.screen_w - self.WIN_W - 8)
        min_y = 48
        max_y = max(min_y, self.screen_h - self.WIN_H - 58)

        if self.x < min_x or self.x > max_x:
            self.vx *= -0.65
        if self.y < min_y or self.y > max_y:
            self.vy *= -0.65

        self.x = max(min_x, min(max_x, self.x))
        self.y = max(min_y, min(max_y, self.y))

    def _move_window(self) -> None:
        self.root.geometry(f"{self.WIN_W}x{self.WIN_H}+{int(self.x)}+{int(self.y)}")

    def _update_particles(self, dt: float) -> None:
        kept = []
        for particle in self.sparkles:
            particle["x"] = float(particle["x"]) + float(particle["vx"]) * (dt / 0.033)
            particle["y"] = float(particle["y"]) + float(particle["vy"]) * (dt / 0.033)
            particle["vy"] = float(particle["vy"]) + 0.025
            particle["life"] = float(particle["life"]) - dt
            if float(particle["life"]) > 0:
                kept.append(particle)
        self.sparkles = kept

    def _start_drag(self, event: tk.Event) -> None:
        self.dragging = True
        self.was_dragged = False
        self.drag_offset_x = event.x
        self.drag_offset_y = event.y
        self.press_screen_x = event.x_root
        self.press_screen_y = event.y_root

    def _drag(self, event: tk.Event) -> None:
        self.was_dragged = True
        self.x = event.x_root - self.drag_offset_x
        self.y = event.y_root - self.drag_offset_y
        self.vx = 0.0
        self.vy = 0.0
        self._keep_on_screen()
        self._move_window()

    def _finish_drag(self, event: tk.Event) -> None:
        self.dragging = False
        moved = self.was_dragged or abs(event.x_root - self.press_screen_x) > 5 or abs(event.y_root - self.press_screen_y) > 5
        if moved:
            self.target_x = self.x
            self.target_y = self.y
            self.bubble("whee!", seconds=2.2)
            self._burst("spark", 9)
        else:
            self.pet()

    def _double_click(self, _event: tk.Event) -> None:
        self.feed()

    def _show_menu(self, event: tk.Event) -> None:
        try:
            self.menu.tk_popup(event.x_root, event.y_root)
        finally:
            self.menu.grab_release()

    def pet(self) -> None:
        self.affection = min(100.0, self.affection + 28.0)
        self.hunger = min(100.0, self.hunger + 1.5)
        self.bubble(random.choice(("prrrp!", "snoot pat!", "best human", "again!")), seconds=3.0)
        self.mouth_until = time.time() + 0.9
        self._burst("heart", 8)
        self._play_sound("Purr")

    def feed(self) -> None:
        self.hunger = max(0.0, self.hunger - 42.0)
        self.affection = min(100.0, self.affection + 12.0)
        self.bubble(random.choice(("nom nom!", "berry!!!", "tiny feast", "cronch!")), seconds=3.2)
        self.mouth_until = time.time() + 1.4
        self._burst("crumb", 12)
        self._play_sound("Pop")

    def chirp(self, message: str, seconds: float = 4.0) -> None:
        self.bubble(message, seconds=seconds)
        self.mouth_until = time.time() + 1.2
        self._burst("spark", 5)
        self._play_sound(random.choice(("Ping", "Glass", "Tink")))
        if self.voice_on.get() and shutil.which("say"):
            phrase = message.replace("?", "")
            self._popen(["say", "-v", "Bells", phrase])

    def bubble(self, text: str, seconds: float = 3.0) -> None:
        self.bubble_text = text
        self.bubble_until = time.time() + seconds

    def _play_sound(self, name: str) -> None:
        if not self.sound_on.get() or not shutil.which("afplay"):
            return

        candidates = (
            f"/System/Library/Sounds/{name}.aiff",
            "/System/Library/Sounds/Ping.aiff",
            "/System/Library/Sounds/Pop.aiff",
        )
        for path in candidates:
            if os.path.exists(path):
                self._popen(["afplay", path])
                return

    def _popen(self, command: list[str]) -> None:
        try:
            subprocess.Popen(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError:
            pass

    def _burst(self, kind: str, count: int) -> None:
        colors = {
            "heart": ("#ff5a7a", "#ff8aa0", "#ffd1dc"),
            "crumb": ("#f8d56b", "#f39c4a", "#fff3a6"),
            "spark": ("#7df6d2", "#f8d56b", "#8d85ff"),
        }[kind]

        origin_x = 148 if self.facing > 0 else 112
        origin_y = 164
        for _ in range(count):
            angle = random.uniform(-math.pi * 0.95, -math.pi * 0.05)
            speed = random.uniform(1.4, 3.4)
            self.sparkles.append(
                {
                    "kind": kind,
                    "x": origin_x + random.uniform(-12, 12),
                    "y": origin_y + random.uniform(-10, 12),
                    "vx": math.cos(angle) * speed,
                    "vy": math.sin(angle) * speed,
                    "life": random.uniform(0.7, 1.25),
                    "color": random.choice(colors),
                    "size": random.uniform(4, 8),
                }
            )

    def _draw(self, now: float) -> None:
        c = self.canvas
        c.delete("all")

        bob = math.sin(self.phase * 1.8) * 2.5
        run = math.sin(self.phase * 2.6)
        mouth_open = now < self.mouth_until

        self._draw_pixel_shadow()
        self._draw_pixel_dragon(int(round(bob)), run, mouth_open)
        self._draw_particles()

        if now < self.bubble_until:
            self._draw_bubble(self.bubble_text, mouth_open)

    def _block(self, x: float, y: float, w: float, h: float, color: str, ox: float, oy: float, scale: int = 5) -> None:
        self.canvas.create_rectangle(
            ox + x * scale,
            oy + y * scale,
            ox + (x + w) * scale,
            oy + (y + h) * scale,
            fill=color,
            outline=color,
        )

    def _draw_pixel_shadow(self) -> None:
        self.canvas.create_oval(58, 224, 204, 240, fill="#52636b", outline="")
        self.canvas.create_oval(86, 226, 178, 236, fill="#6f858c", outline="")

    def _draw_pixel_dragon(self, bob: int, run: float, mouth_open: bool) -> None:
        ox = 15
        oy = 52 + bob
        k = self.INK
        blue = self.BODY
        blue_dark = self.BODY_DARK
        blue_light = self.BODY_LIGHT
        wing = self.WING
        wing_light = self.WING_LIGHT
        yellow = self.BELLY
        yellow_dark = "#f6a844"
        pink = "#ff8aa0"
        red = "#ff686e"
        red_dark = "#ef3e43"
        white = "#ffffff"
        eye = "#33272d"
        flap = -1 if math.sin(self.phase * 3.8) > 0 else 0
        foot_a = 1 if run > 0.1 else 0
        foot_b = 1 if run < -0.1 else 0

        # Tail behind the body.
        for rect in ((34, 29, 7, 4), (39, 26, 3, 4), (41, 22, 3, 5), (42, 18, 2, 5), (40, 17, 4, 2)):
            self._block(*rect, k, ox, oy)
        for rect in ((35, 29, 5, 3), (39, 27, 2, 3), (41, 23, 2, 4), (42, 19, 1, 4)):
            self._block(*rect, blue_dark, ox, oy)
        self._block(36, 30, 1, 1, pink, ox, oy)
        self._block(39, 31, 1, 1, pink, ox, oy)
        self._block(42, 18, 2, 1, red, ox, oy)

        # Tiny flappy wings.
        for rect in ((2, 18 + flap, 4, 3), (1, 21 + flap, 5, 4), (4, 16 + flap, 3, 3), (5, 25 + flap, 3, 2)):
            self._block(*rect, k, ox, oy)
        for rect in ((3, 19 + flap, 3, 2), (2, 22 + flap, 4, 2), (5, 17 + flap, 1, 2), (5, 24 + flap, 2, 1)):
            self._block(*rect, wing, ox, oy)
        self._block(3, 20 + flap, 2, 1, wing_light, ox, oy)

        for rect in ((40, 18 + flap, 4, 3), (40, 21 + flap, 5, 4), (38, 16 + flap, 3, 3), (38, 25 + flap, 3, 2)):
            self._block(*rect, k, ox, oy)
        for rect in ((41, 19 + flap, 3, 2), (41, 22 + flap, 4, 2), (39, 17 + flap, 1, 2), (39, 24 + flap, 2, 1)):
            self._block(*rect, wing, ox, oy)
        self._block(41, 20 + flap, 2, 1, wing_light, ox, oy)

        # Little body, belly, paws, and feet.
        for rect in ((15, 28, 18, 8), (16, 36, 5, 2), (27, 36, 5, 2), (13, 29, 5, 3), (31, 29, 5, 3)):
            self._block(*rect, k, ox, oy)
        self._block(17, 29, 14, 7, blue_dark, ox, oy)
        self._block(20, 29, 8, 8, yellow, ox, oy)
        self._block(20, 31, 8, 1, "#ffe796", ox, oy)
        self._block(21, 34, 6, 1, yellow_dark, ox, oy)
        self._block(17, 36 + foot_a, 4, 1, blue_light, ox, oy)
        self._block(28, 36 + foot_b, 4, 1, blue_light, ox, oy)
        self._block(14, 29, 3, 2, blue, ox, oy)
        self._block(32, 29, 3, 2, blue, ox, oy)

        # Horns and soft fire tuft.
        for rect in ((7, 5, 4, 2), (8, 7, 5, 2), (10, 9, 4, 2), (12, 11, 3, 2), (35, 5, 4, 2), (33, 7, 5, 2), (32, 9, 4, 2), (31, 11, 3, 2)):
            self._block(*rect, k, ox, oy)
        for rect in ((8, 5, 3, 2), (9, 7, 4, 2), (11, 9, 3, 2), (13, 11, 1, 1), (35, 5, 3, 2), (33, 7, 4, 2), (32, 9, 3, 2), (32, 11, 1, 1)):
            self._block(*rect, yellow, ox, oy)
        self._block(12, 10, 2, 1, yellow_dark, ox, oy)
        self._block(32, 10, 2, 1, yellow_dark, ox, oy)

        for rect in ((20, 0, 7, 2), (19, 2, 8, 3), (18, 5, 6, 4), (19, 9, 9, 2), (24, 4, 3, 6)):
            self._block(*rect, k, ox, oy)
        for rect in ((21, 1, 5, 2), (20, 3, 5, 3), (19, 6, 5, 4), (20, 9, 6, 1)):
            self._block(*rect, red, ox, oy)
        self._block(24, 3, 2, 7, red_dark, ox, oy)
        self._block(22, 1, 2, 1, "#ff9a9f", ox, oy)

        # Huge baby head.
        for rect in ((10, 9, 28, 1), (8, 10, 32, 2), (7, 12, 34, 4), (6, 16, 36, 8), (7, 24, 34, 3), (9, 27, 30, 2), (12, 29, 24, 1)):
            self._block(*rect, k, ox, oy)
        self._block(11, 10, 26, 2, blue_light, ox, oy)
        self._block(8, 12, 32, 4, blue, ox, oy)
        self._block(7, 16, 34, 8, blue, ox, oy)
        self._block(9, 24, 30, 3, blue_dark, ox, oy)
        self._block(12, 27, 24, 1, blue_dark, ox, oy)
        self._block(10, 13, 12, 3, "#84e6fb", ox, oy)
        self._block(24, 10, 1, 5, blue_dark, ox, oy)
        self._block(26, 10, 1, 4, blue_dark, ox, oy)
        self._block(22, 12, 1, 3, "#37afd5", ox, oy)

        if self.affection > 86:
            self._block(11, 22, 4, 2, pink, ox, oy)
            self._block(33, 22, 4, 2, pink, ox, oy)

        blink = math.sin(self.phase * 0.7) > 0.985
        if blink:
            self._block(13, 18, 7, 1, k, ox, oy)
            self._block(29, 18, 7, 1, k, ox, oy)
        else:
            for rect in ((13, 16, 7, 7), (29, 16, 7, 7)):
                self._block(*rect, k, ox, oy)
            self._block(14, 17, 5, 5, eye, ox, oy)
            self._block(30, 17, 5, 5, eye, ox, oy)
            self._block(15, 17, 2, 2, white, ox, oy)
            self._block(31, 17, 2, 2, white, ox, oy)
            self._block(18, 21, 1, 1, white, ox, oy)
            self._block(34, 21, 1, 1, white, ox, oy)

        if mouth_open:
            self._block(22, 23, 5, 3, k, ox, oy)
            self._block(23, 24, 3, 2, "#ff8fb1", ox, oy)
            self._block(22, 23, 1, 1, white, ox, oy)
            self._block(26, 23, 1, 1, white, ox, oy)
        else:
            for rect in ((20, 23, 1, 1), (21, 24, 2, 1), (23, 23, 2, 1), (25, 24, 2, 1), (27, 23, 1, 1)):
                self._block(*rect, k, ox, oy)
            self._block(22, 25, 1, 1, white, ox, oy)
            self._block(26, 25, 1, 1, white, ox, oy)

        self._block(20, 22, 2, 1, "#36a7cb", ox, oy)
        self._block(27, 22, 2, 1, "#36a7cb", ox, oy)

    def _x(self, x: float) -> float:
        return self.WIN_W - x if self.facing < 0 else x

    def _oval(self, x1: float, y1: float, x2: float, y2: float) -> tuple[float, float, float, float]:
        tx1 = self._x(x1)
        tx2 = self._x(x2)
        return min(tx1, tx2), y1, max(tx1, tx2), y2

    def _points(self, values: tuple[float, ...] | list[float]) -> list[float]:
        points: list[float] = []
        for index in range(0, len(values), 2):
            points.extend((self._x(values[index]), values[index + 1]))
        return points

    def _draw_shadow(self, x: float, y: float) -> None:
        self.canvas.create_oval(x - 54, y - 8, x + 54, y + 9, fill="#092534", outline="")

    def _draw_tail(self, bob: float) -> None:
        c = self.canvas
        c.create_line(
            self._points((82, 126 + bob, 45, 132 + bob, 22, 112 + bob, 18, 92 + bob)),
            fill=self.BODY_DARK,
            width=20,
            smooth=True,
            capstyle=tk.ROUND,
            joinstyle=tk.ROUND,
        )
        c.create_line(
            self._points((86, 122 + bob, 49, 127 + bob, 28, 111 + bob, 24, 94 + bob)),
            fill=self.BODY,
            width=13,
            smooth=True,
            capstyle=tk.ROUND,
            joinstyle=tk.ROUND,
        )
        c.create_polygon(
            self._points((12, 83 + bob, 31, 93 + bob, 18, 105 + bob)),
            fill=self.SCARF,
            outline=self.INK,
            width=2,
        )

    def _draw_wings(self, bob: float, wing: float) -> None:
        c = self.canvas
        back = self._points((94, 102 + bob, 63, 66 + bob - wing, 60, 123 + bob, 84, 120 + bob))
        front = self._points((129, 98 + bob, 178, 63 + bob - wing, 170, 126 + bob, 138, 121 + bob))
        for points in (back, front):
            c.create_polygon(points, fill=self.WING, outline=self.INK, width=2, smooth=True)
        c.create_line(
            self._points((129, 100 + bob, 174, 67 + bob - wing, 154, 113 + bob)),
            fill=self.WING_LIGHT,
            width=3,
            smooth=True,
            capstyle=tk.ROUND,
        )

    def _draw_body(self, bob: float, run: float) -> None:
        c = self.canvas
        leg_a = run * 5
        leg_b = -run * 5

        c.create_oval(*self._oval(76, 93 + bob, 154, 156 + bob), fill=self.BODY, outline=self.INK, width=3)
        c.create_oval(*self._oval(96, 112 + bob, 144, 154 + bob), fill=self.BELLY, outline=self.INK, width=2)

        for x, y in ((84, 92), (99, 82), (116, 78), (133, 83)):
            c.create_polygon(
                self._points((x, y + bob, x + 9, y - 17 + bob, x + 18, y + bob)),
                fill=self.BELLY,
                outline=self.INK,
                width=2,
            )

        self._draw_leg(89, 148 + bob, leg_a)
        self._draw_leg(133, 148 + bob, leg_b)
        self._draw_arm(139, 120 + bob, run)

        c.create_oval(*self._oval(126, 70 + bob, 184, 124 + bob), fill=self.BODY, outline=self.INK, width=3)
        c.create_oval(*self._oval(158, 91 + bob, 204, 123 + bob), fill=self.BODY_LIGHT, outline=self.INK, width=2)

        c.create_polygon(
            self._points((138, 73 + bob, 129, 49 + bob, 153, 67 + bob)),
            fill="#f4f0ff",
            outline=self.INK,
            width=2,
        )
        c.create_polygon(
            self._points((163, 71 + bob, 169, 47 + bob, 181, 74 + bob)),
            fill="#f4f0ff",
            outline=self.INK,
            width=2,
        )
        c.create_polygon(
            self._points((133, 83 + bob, 121, 68 + bob, 143, 75 + bob)),
            fill=self.WING_LIGHT,
            outline=self.INK,
            width=2,
        )

        c.create_line(
            self._points((120, 119 + bob, 151, 126 + bob, 180, 112 + bob)),
            fill=self.SCARF,
            width=7,
            smooth=True,
            capstyle=tk.ROUND,
        )
        c.create_polygon(
            self._points((151, 126 + bob, 166, 141 + bob, 146, 142 + bob)),
            fill=self.SCARF,
            outline=self.INK,
            width=2,
        )

        self._draw_face(bob)

    def _draw_leg(self, x: float, y: float, swing: float) -> None:
        c = self.canvas
        foot_x = x + swing
        c.create_line(
            self._points((x, y - 8, foot_x, y + 9)),
            fill=self.INK,
            width=9,
            capstyle=tk.ROUND,
        )
        c.create_line(
            self._points((x, y - 8, foot_x, y + 9)),
            fill=self.BODY_DARK,
            width=6,
            capstyle=tk.ROUND,
        )
        c.create_oval(*self._oval(foot_x - 8, y + 4, foot_x + 16, y + 17), fill=self.BODY_LIGHT, outline=self.INK, width=2)

    def _draw_arm(self, x: float, y: float, run: float) -> None:
        wave = math.sin(self.phase * 3.0) * 4
        self.canvas.create_line(
            self._points((x, y, x + 22, y + 8 + wave + run)),
            fill=self.INK,
            width=8,
            capstyle=tk.ROUND,
        )
        self.canvas.create_line(
            self._points((x, y, x + 22, y + 8 + wave + run)),
            fill=self.BODY_LIGHT,
            width=5,
            capstyle=tk.ROUND,
        )

    def _draw_face(self, bob: float) -> None:
        c = self.canvas
        blink = math.sin(self.phase * 0.7) > 0.985

        if blink:
            c.create_line(self._points((151, 91 + bob, 161, 91 + bob)), fill=self.INK, width=3, capstyle=tk.ROUND)
            c.create_line(self._points((176, 94 + bob, 186, 94 + bob)), fill=self.INK, width=3, capstyle=tk.ROUND)
        else:
            c.create_oval(*self._oval(149, 84 + bob, 162, 98 + bob), fill="white", outline=self.INK, width=2)
            c.create_oval(*self._oval(176, 88 + bob, 189, 102 + bob), fill="white", outline=self.INK, width=2)
            c.create_oval(*self._oval(154, 89 + bob, 160, 96 + bob), fill=self.INK, outline="")
            c.create_oval(*self._oval(181, 93 + bob, 187, 100 + bob), fill=self.INK, outline="")

        c.create_oval(*self._oval(190, 103 + bob, 194, 107 + bob), fill=self.INK, outline="")
        c.create_oval(*self._oval(176, 101 + bob, 180, 105 + bob), fill=self.INK, outline="")
        c.create_oval(*self._oval(146, 102 + bob, 156, 109 + bob), fill="#ff93a9", outline="")

        if time.time() < self.mouth_until:
            c.create_oval(*self._oval(178, 111 + bob, 192, 121 + bob), fill="#4b1624", outline=self.INK, width=2)
            c.create_oval(*self._oval(184, 116 + bob, 191, 121 + bob), fill="#ff93a9", outline="")
        else:
            c.create_arc(
                *self._oval(178, 106 + bob, 195, 119 + bob),
                start=190 if self.facing > 0 else -10,
                extent=125,
                style=tk.ARC,
                outline=self.INK,
                width=2,
            )

    def _draw_particles(self) -> None:
        for particle in self.sparkles:
            life = float(particle["life"])
            size = float(particle["size"]) * max(0.35, min(1.0, life))
            x = float(particle["x"])
            y = float(particle["y"])
            color = str(particle["color"])
            kind = str(particle["kind"])

            if kind == "heart":
                self._heart(x, y, size, color)
            elif kind == "crumb":
                self.canvas.create_oval(x - size, y - size * 0.7, x + size, y + size * 0.7, fill=color, outline=self.INK, width=1)
            else:
                self._star(x, y, size, color)

    def _heart(self, x: float, y: float, size: float, color: str) -> None:
        c = self.canvas
        c.create_oval(x - size, y - size, x, y, fill=color, outline="")
        c.create_oval(x, y - size, x + size, y, fill=color, outline="")
        c.create_polygon(x - size, y - size * 0.35, x + size, y - size * 0.35, x, y + size * 1.1, fill=color, outline="")

    def _star(self, x: float, y: float, size: float, color: str) -> None:
        points = []
        for i in range(10):
            radius = size if i % 2 == 0 else size * 0.45
            angle = -math.pi / 2 + i * math.pi / 5
            points.extend((x + math.cos(angle) * radius, y + math.sin(angle) * radius))
        self.canvas.create_polygon(points, fill=color, outline="")

    def _draw_bubble(self, text: str, mouth_open: bool) -> None:
        x1, y1, x2, y2 = 30, 8, 230, 50
        self._rounded_rect(x1, y1, x2, y2, 12, fill="#fffaf2", outline=self.INK, width=3)
        tail_x = 145 if self.facing > 0 else 115
        self.canvas.create_polygon(
            tail_x - 9,
            y2 - 1,
            tail_x + 8,
            y2 - 1,
            tail_x + (17 if self.facing > 0 else -17),
            y2 + 16,
            fill="#fffaf2",
            outline=self.INK,
            width=2,
        )
        self.canvas.create_text(
            (x1 + x2) / 2,
            (y1 + y2) / 2 - (1 if mouth_open else 0),
            text=text,
            fill=self.INK,
            font=("Avenir Next", 16, "bold"),
            width=x2 - x1 - 18,
        )

    def _rounded_rect(self, x1: float, y1: float, x2: float, y2: float, radius: float, **kwargs: object) -> None:
        points = [
            x1 + radius,
            y1,
            x2 - radius,
            y1,
            x2,
            y1,
            x2,
            y1 + radius,
            x2,
            y2 - radius,
            x2,
            y2,
            x2 - radius,
            y2,
            x1 + radius,
            y2,
            x1,
            y2,
            x1,
            y2 - radius,
            x1,
            y1 + radius,
            x1,
            y1,
        ]
        self.canvas.create_polygon(points, smooth=True, **kwargs)


if __name__ == "__main__":
    DragonPet().run()
