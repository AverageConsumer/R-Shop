/**
 * R-Shop V9 — Design-Aligned Visual Novel Engine
 * Mirrors: PixelMascotPainter, ChatBubble typewriter, ConsoleHud, AudioManager
 */
document.addEventListener('DOMContentLoaded', () => {

    // ===================== AUDIO =====================
    const sfx = {
        ambience: document.getElementById('sfx-ambience'),
        typing: document.getElementById('sfx-typing'),
        nav: document.getElementById('sfx-nav'),
        confirm: document.getElementById('sfx-confirm'),
    };
    if (sfx.ambience) sfx.ambience.volume = 0.35;
    if (sfx.typing) sfx.typing.volume = 0.5;
    if (sfx.nav) sfx.nav.volume = 0.65;
    if (sfx.confirm) sfx.confirm.volume = 0.8;

    // ===================== PIXEL MASCOT (matches _PixelMascotPainter) =====================
    const BODY = '#FF6B6B';
    const DARK = '#CC5555';
    const EYE = '#1A1A2E';
    const HI = '#FFB3B3';

    function drawMascot(canvas) {
        const ctx = canvas.getContext('2d');
        const s = canvas.width / 8; // 8x8 grid
        ctx.clearRect(0, 0, canvas.width, canvas.height);

        function px(x, y, color) {
            ctx.fillStyle = color;
            ctx.fillRect(x * s, y * s, s, s);
        }

        // Antenna
        px(3, 1, BODY); px(4, 1, HI);
        // Head row
        px(2, 2, BODY); px(3, 2, HI); px(4, 2, BODY); px(5, 2, BODY);
        // Body row 1 (with eyes)
        px(1, 3, BODY); px(2, 3, EYE); px(3, 3, BODY); px(4, 3, BODY); px(5, 3, EYE); px(6, 3, BODY);
        // Body row 2
        px(1, 4, BODY); px(2, 4, BODY); px(3, 4, BODY); px(4, 4, BODY); px(5, 4, BODY); px(6, 4, BODY);
        // Feet (with shadow)
        px(2, 5, DARK); px(3, 5, BODY); px(4, 5, BODY); px(5, 5, DARK);
    }

    // Draw mascot on boot screen and inline chat
    drawMascot(document.getElementById('mascotCanvas'));
    drawMascot(document.getElementById('mascotSmall'));

    // ===================== PARTICLE SYSTEM =====================
    const canvas = document.getElementById('particleCanvas');
    const ctx = canvas.getContext('2d');
    let particles = [];
    const COUNT = 40;
    let dpr = window.devicePixelRatio || 1;
    let lastT = performance.now();

    function resize() {
        dpr = window.devicePixelRatio || 1;
        canvas.width = innerWidth * dpr;
        canvas.height = innerHeight * dpr;
        canvas.style.width = innerWidth + 'px';
        canvas.style.height = innerHeight + 'px';
        ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    }
    resize();
    addEventListener('resize', resize);

    for (let i = 0; i < COUNT; i++) {
        particles.push({
            x: Math.random() * innerWidth,
            y: Math.random() * innerHeight,
            s: Math.random() * 2 + 0.5,
            vy: -(Math.random() * 18 + 5),
            vx: (Math.random() - 0.5) * 8,
            o: Math.random() * 0.35 + 0.05,
        });
    }

    function tick(now) {
        const dt = Math.min((now - lastT) / 1000, 0.1);
        lastT = now;
        ctx.clearRect(0, 0, innerWidth, innerHeight);
        for (const p of particles) {
            // Red-tinted particles to match the app's primary color
            ctx.fillStyle = `rgba(255, 107, 107, ${p.o})`;
            ctx.fillRect(p.x, p.y, p.s, p.s);
            p.y += p.vy * dt;
            p.x += p.vx * dt;
            if (p.y < -5) {
                p.x = Math.random() * innerWidth;
                p.y = innerHeight + 5;
                p.o = Math.random() * 0.35 + 0.05;
            }
        }
        requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);

    // ===================== BOOT SEQUENCE =====================
    const bootScreen = document.getElementById('bootScreen');
    const experience = document.getElementById('experience');

    document.getElementById('bootBtn').addEventListener('click', () => {
        if (sfx.ambience) sfx.ambience.play().catch(() => { });
        bootScreen.classList.add('done');
        setTimeout(() => {
            experience.classList.add('active');
            setTimeout(() => {
                dom.chatArea.classList.add('visible');
                dom.hud.classList.add('visible');
                playNode(0);
            }, 500);
        }, 800);
    });

    // ===================== STORY ENGINE =====================
    const dom = {
        chatArea: document.getElementById('chatArea'),
        chatText: document.getElementById('chatText'),
        chatCursor: document.getElementById('chatCursor'),
        showcase: document.getElementById('showcase'),
        showcaseImg: document.getElementById('showcaseImg'),
        showcaseLabel: document.getElementById('showcaseLabel'),
        hud: document.getElementById('consoleHud'),
        hudPrev: document.getElementById('hudPrev'),
        hudNext: document.getElementById('hudNext'),
        finale: document.getElementById('finale'),
        stepCurrent: document.querySelector('.step-current'),
    };

    const story = [
        {
            text: "Hey there! I'm Pixel, your R-Shop guide. Ready to explore your retro game collection?",
            action: () => { }
        },
        {
            text: "Getting games onto your handheld has always been a pain. SD card juggling, messy folder structures, no integrated store...",
            action: () => { }
        },
        {
            text: "<strong>Not anymore.</strong> Check out this fully controller-native interface. Every button, every screen — built for your D-pad.",
            action: () => showScreenshot('assets/console_list.png', 'Console Overview')
        },
        {
            text: "Browse your entire library. Every system, every game, gorgeous boxart — all in one place.",
            action: () => showScreenshot('assets/rom_list.png', 'Game Library')
        },
        {
            text: "I connect <strong>directly</strong> to RomM, SMB shares, FTP servers, and HTTP sources. Configure once, sync forever.",
            action: () => showScreenshot('assets/smb_setup.png', 'Source Configuration')
        },
        {
            text: "Downloads run in the background. ZIP extraction is <strong>automatic</strong>. Your games arrive ready to play.",
            action: () => {
                showScreenshot('assets/download_queue.png', 'Download Engine');
                fadeAudio(sfx.ambience, 0.35, 0.65, 1500);
            }
        },
        {
            text: "Free. Open Source. Built by a retro gamer, for retro gamers. Ready when you are.",
            isFinale: true,
            action: () => {
                // Stop any typing sound immediately
                endTyping();
                play(sfx.confirm);
                dom.showcase.classList.remove('active');
                dom.chatArea.classList.remove('visible');
                dom.hud.classList.remove('visible');
                setTimeout(() => dom.finale.classList.add('active'), 500);
            }
        }
    ];

    let idx = 0, typing = false, timer;

    function playNode(i) {
        if (i >= story.length) return;
        dom.stepCurrent.textContent = i + 1;
        const node = story[i];
        node.action();

        // Don't start typing on the finale node (chat bubble is already hidden)
        if (!node.isFinale) {
            typeText(node.text);
        }

        // Update HUD visibility
        dom.hudPrev.style.display = i === 0 ? 'none' : 'flex';
        if (i === story.length - 1) dom.hudNext.style.display = 'none';
    }

    function typeText(text) {
        if (typing) return;
        typing = true;
        dom.chatText.innerHTML = '';
        dom.chatCursor.classList.remove('done');
        let ci = 0;

        if (sfx.typing) { sfx.typing.currentTime = 0; sfx.typing.loop = true; sfx.typing.play().catch(() => { }); }

        timer = setInterval(() => {
            if (ci < text.length) {
                while (ci < text.length && text[ci] === '<') {
                    const end = text.indexOf('>', ci);
                    if (end !== -1) ci = end + 1; else break;
                }
                ci++;
                dom.chatText.innerHTML = text.substring(0, ci);
            } else {
                endTyping();
            }
        }, 28);
    }

    function endTyping() {
        clearInterval(timer);
        typing = false;
        dom.chatCursor.classList.add('done');
        if (sfx.typing) { sfx.typing.pause(); sfx.typing.currentTime = 0; }
    }

    function skip() {
        clearInterval(timer);
        dom.chatText.innerHTML = story[idx].text;
        endTyping();
    }

    // ===================== VISUAL FX =====================
    function showScreenshot(src, label) {
        dom.showcaseImg.src = src;
        dom.showcaseLabel.textContent = label;
        dom.showcase.classList.add('active');
    }

    function play(a) { if (a) { a.currentTime = 0; a.play().catch(() => { }); } }

    function fadeAudio(a, from, to, ms) {
        if (!a) return;
        a.volume = from;
        const steps = 20, step = (to - from) / steps;
        let i = 0;
        const iv = setInterval(() => {
            i++;
            a.volume = Math.max(0, Math.min(1, from + step * i));
            if (i >= steps) clearInterval(iv);
        }, ms / steps);
    }

    // ===================== INPUT =====================
    function advance() {
        if (typing) { skip(); return; }
        if (idx < story.length - 1) {
            play(sfx.nav);
            idx++;
            playNode(idx);
        }
    }

    function goBack() {
        if (typing) skip();
        if (idx > 0) {
            play(sfx.nav);
            idx--;
            if (idx < 2) dom.showcase.classList.remove('active');
            playNode(idx);
        }
    }

    // Click ANYWHERE on the experience to advance (the whole page is a tap target)
    experience.addEventListener('click', (e) => {
        // Don't intercept finale buttons or HUD back button
        if (e.target.closest('.btn-primary, .btn-ghost')) return;
        if (e.target.closest('#hudPrev')) { goBack(); return; }
        advance();
    });

    // Keyboard support
    addEventListener('keydown', (e) => {
        if (e.key === 'Enter' || e.key === ' ' || e.key === 'ArrowRight') { e.preventDefault(); advance(); }
        if (e.key === 'Backspace' || e.key === 'ArrowLeft') { e.preventDefault(); goBack(); }
    });
});
