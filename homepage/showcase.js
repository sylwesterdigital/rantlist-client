(() => {
  'use strict';

  const section = document.getElementById('showcase');
  const viewport = document.getElementById('showcaseViewport');
  const track = document.getElementById('showcaseTrack');
  const dots = document.getElementById('showcaseDots');
  const eyebrow = document.getElementById('showcaseEyebrow');
  const heading = document.getElementById('showcaseHeading');
  const description = document.getElementById('showcaseDescription');
  if (!section || !viewport || !track || !dots) return;

  let cards = [];
  let activeIndex = 0;
  let currentTranslate = 0;
  let pointerId = null;
  let pointerStartX = 0;
  let pointerLastX = 0;
  let dragStartTranslate = 0;
  let dragging = false;
  const hlsPlayers = new Map();

  const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

  function hlsUrl(raw) {
    try {
      const url = new URL(String(raw || ''), window.location.href);
      if (url.protocol !== 'https:' || !url.pathname.toLowerCase().endsWith('.m3u8')) return '';
      return url.href;
    } catch (_) {
      return '';
    }
  }

  function stopOtherVideos(index) {
    cards.forEach((card, cardIndex) => {
      if (cardIndex === index) return;
      const video = card.querySelector('video');
      if (video && !video.paused) video.pause();
    });
  }

  function attachStream(card) {
    const video = card.querySelector('video');
    if (!video || video.dataset.streamAttached === 'true') return;
    const url = hlsUrl(card.dataset.hls);
    const status = card.querySelector('.showcase-video-status');
    if (!url) {
      if (status) status.textContent = 'Video stream is unavailable.';
      return;
    }

    video.dataset.streamAttached = 'true';
    if (video.canPlayType('application/vnd.apple.mpegurl')) {
      video.src = url;
      return;
    }

    if (window.Hls && window.Hls.isSupported()) {
      const hls = new window.Hls({
        enableWorker: true,
        lowLatencyMode: false,
        backBufferLength: 30,
        maxBufferLength: 30
      });
      hls.loadSource(url);
      hls.attachMedia(video);
      hls.on(window.Hls.Events.ERROR, (_event, data) => {
        if (!data || !data.fatal) return;
        if (status) status.textContent = 'Unable to play this HLS stream.';
      });
      hlsPlayers.set(video, hls);
      return;
    }

    video.dataset.streamAttached = 'false';
    if (status) status.textContent = 'This browser does not support HLS playback.';
  }

  function setPosition(animate = true) {
    if (!cards.length) return;
    const card = cards[activeIndex];
    if (!card) return;
    const target = (viewport.clientWidth / 2) - (card.offsetLeft + card.offsetWidth / 2);
    currentTranslate = target;
    track.classList.toggle('is-dragging', !animate);
    track.style.transform = `translate3d(${target}px,0,0)`;
    if (animate) requestAnimationFrame(() => track.classList.remove('is-dragging'));
  }

  function activate(index, animate = true) {
    if (!cards.length) return;
    activeIndex = clamp(index, 0, cards.length - 1);
    cards.forEach((card, cardIndex) => {
      const active = cardIndex === activeIndex;
      card.classList.toggle('is-active', active);
      card.setAttribute('aria-hidden', active ? 'false' : 'true');
      const dot = dots.children[cardIndex];
      if (dot) {
        dot.classList.toggle('is-active', active);
        dot.setAttribute('aria-current', active ? 'true' : 'false');
      }
    });
    attachStream(cards[activeIndex]);
    stopOtherVideos(activeIndex);
    setPosition(animate);
  }

  function createCard(item, index, total) {
    const card = document.createElement('article');
    card.className = 'showcase-card';
    card.dataset.hls = item.hls;
    card.setAttribute('aria-label', `${item.title}. Video ${index + 1} of ${total}`);

    const media = document.createElement('div');
    media.className = 'showcase-media';

    const video = document.createElement('video');
    video.controls = true;
    video.playsInline = true;
    video.preload = 'metadata';
    video.setAttribute('webkit-playsinline', '');
    video.setAttribute('aria-label', item.title);
    if (item.poster) video.poster = item.poster;
    video.addEventListener('play', () => stopOtherVideos(index));

    const overlay = document.createElement('div');
    overlay.className = 'showcase-overlay';
    const number = document.createElement('span');
    number.className = 'showcase-number';
    number.textContent = String(index + 1).padStart(2, '0');
    const title = document.createElement('strong');
    title.textContent = item.title;
    overlay.append(number, title);

    const status = document.createElement('div');
    status.className = 'showcase-video-status';
    status.setAttribute('aria-live', 'polite');

    media.append(video, overlay, status);
    card.append(media);
    return card;
  }

  function createDot(index, title) {
    const button = document.createElement('button');
    button.className = 'showcase-dot';
    button.type = 'button';
    button.setAttribute('aria-label', `Show ${title}`);
    button.addEventListener('click', () => activate(index));
    return button;
  }

  function beginPointer(event) {
    if (event.button !== undefined && event.button !== 0) return;
    if (event.target.closest('.showcase-dots')) return;
    pointerId = event.pointerId;
    pointerStartX = event.clientX;
    pointerLastX = event.clientX;
    dragStartTranslate = currentTranslate;
    dragging = false;
  }

  function movePointer(event) {
    if (pointerId === null || event.pointerId !== pointerId) return;
    pointerLastX = event.clientX;
    const delta = pointerLastX - pointerStartX;
    if (!dragging && Math.abs(delta) < 8) return;
    if (!dragging) {
      dragging = true;
      viewport.classList.add('is-dragging');
      track.classList.add('is-dragging');
      try { viewport.setPointerCapture(pointerId); } catch (_) {}
    }
    if (event.cancelable) event.preventDefault();
    track.style.transform = `translate3d(${dragStartTranslate + delta}px,0,0)`;
  }

  function endPointer(event) {
    if (pointerId === null || event.pointerId !== pointerId) return;
    const delta = pointerLastX - pointerStartX;
    if (dragging) {
      const threshold = Math.min(110, Math.max(48, (cards[activeIndex]?.offsetWidth || 600) * 0.12));
      if (Math.abs(delta) >= threshold) activate(activeIndex + (delta < 0 ? 1 : -1));
      else activate(activeIndex);
    }
    try { viewport.releasePointerCapture(pointerId); } catch (_) {}
    pointerId = null;
    dragging = false;
    viewport.classList.remove('is-dragging');
    track.classList.remove('is-dragging');
  }

  async function load() {
    try {
      const response = await fetch('./content.json', {cache: 'no-store'});
      if (!response.ok) throw new Error(`content.json returned ${response.status}`);
      const payload = await response.json();
      const showcase = payload && payload.showcase;
      const videos = showcase && Array.isArray(showcase.videos) ? showcase.videos : [];
      if (!showcase || showcase.enabled === false || videos.length === 0) {
        section.hidden = true;
        return;
      }

      if (eyebrow && typeof showcase.eyebrow === 'string') eyebrow.textContent = showcase.eyebrow;
      if (heading && typeof showcase.heading === 'string') heading.textContent = showcase.heading;
      if (description && typeof showcase.description === 'string') description.textContent = showcase.description;

      const items = videos.map((item, index) => ({
        title: String(item && item.title || `Rantlist video ${index + 1}`).trim().slice(0, 120),
        hls: hlsUrl(item && item.hls),
        poster: item && item.poster ? String(item.poster) : ''
      })).filter(item => item.hls);
      if (!items.length) {
        section.hidden = true;
        return;
      }

      track.replaceChildren();
      dots.replaceChildren();
      cards = items.map((item, index) => createCard(item, index, items.length));
      cards.forEach(card => track.appendChild(card));
      items.forEach((item, index) => dots.appendChild(createDot(index, item.title)));
      section.hidden = false;
      requestAnimationFrame(() => activate(0, false));
    } catch (error) {
      console.error('Rantlist showcase failed to load:', error);
      section.hidden = true;
    }
  }

  viewport.addEventListener('pointerdown', beginPointer);
  viewport.addEventListener('pointermove', movePointer, {passive: false});
  viewport.addEventListener('pointerup', endPointer);
  viewport.addEventListener('pointercancel', endPointer);
  viewport.addEventListener('keydown', event => {
    if (event.key === 'ArrowLeft') {
      event.preventDefault();
      activate(activeIndex - 1);
    } else if (event.key === 'ArrowRight') {
      event.preventDefault();
      activate(activeIndex + 1);
    }
  });
  window.addEventListener('resize', () => requestAnimationFrame(() => setPosition(false)));
  window.addEventListener('pagehide', () => {
    hlsPlayers.forEach(hls => hls.destroy());
    hlsPlayers.clear();
  });

  load();
})();
