/* Bean & Roast Co. showcase — scroll reveals + query tabs.
   One easing curve everywhere: cubic-bezier(0.22, 1, 0.36, 1) (in CSS). */

(function () {
  'use strict';

  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ---- scroll reveals: IntersectionObserver, animate once ---- */
  var revealed = document.querySelectorAll('.reveal');

  if (reduceMotion || !('IntersectionObserver' in window)) {
    revealed.forEach(function (el) { el.classList.add('is-visible'); });
  } else {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (!entry.isIntersecting) return;
        var el = entry.target;

        // stagger siblings that reveal together
        var siblings = Array.prototype.filter.call(
          el.parentElement.querySelectorAll('.reveal'),
          function (s) { return !s.classList.contains('is-visible'); }
        );
        var idx = siblings.indexOf(el);
        if (idx > 0) el.style.transitionDelay = Math.min(idx * 90, 450) + 'ms';

        el.classList.add('is-visible');
        observer.unobserve(el);
      });
    }, { threshold: 0.12, rootMargin: '0px 0px -6% 0px' });

    revealed.forEach(function (el) { observer.observe(el); });
  }

  /* ---- hero load choreography: stagger kicker → h1 → lede → ctas ---- */
  var heroItems = document.querySelectorAll('.hero .reveal');
  heroItems.forEach(function (el, i) {
    el.style.transitionDelay = (i * 80) + 'ms';
  });

  /* ---- query tabs ---- */
  var tabs = Array.prototype.slice.call(document.querySelectorAll('.tab'));

  function activate(key) {
    tabs.forEach(function (tab) {
      var on = tab.dataset.tab === key;
      tab.classList.toggle('is-active', on);
      tab.setAttribute('aria-selected', on ? 'true' : 'false');
      var panel = document.getElementById('panel-' + tab.dataset.tab);
      if (!panel) return;
      if (on) {
        panel.hidden = false;
        panel.classList.add('is-visible'); // panels are already in view; show instantly
      } else {
        panel.hidden = true;
      }
    });
  }

  tabs.forEach(function (tab) {
    tab.addEventListener('click', function () { activate(tab.dataset.tab); });
    tab.addEventListener('keydown', function (e) {
      var i = tabs.indexOf(tab);
      if (e.key === 'ArrowRight') tabs[(i + 1) % tabs.length].focus();
      if (e.key === 'ArrowLeft') tabs[(i - 1 + tabs.length) % tabs.length].focus();
    });
  });
})();
