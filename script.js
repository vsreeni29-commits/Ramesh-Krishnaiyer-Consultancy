const header = document.querySelector('[data-header]');
const progressBar = document.querySelector('.scroll-progress span');
const menuToggle = document.querySelector('[data-menu-toggle]');
const navigation = document.querySelector('[data-navigation]');
const filterButtons = [...document.querySelectorAll('[data-filter]')];
const serviceCards = [...document.querySelectorAll('.service-card')];
const filterStatus = document.querySelector('[data-filter-status]');
const dialog = document.querySelector('#inquiry-dialog');
const inquiryForm = document.querySelector('[data-inquiry-form]');
const serviceSelect = document.querySelector('[data-service-select]');
const toast = document.querySelector('[data-toast]');
const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

document.querySelector('[data-year]').textContent = new Date().getFullYear();

function updateScrollUI() {
  const scrollable = document.documentElement.scrollHeight - window.innerHeight;
  const progress = scrollable > 0 ? window.scrollY / scrollable : 0;
  progressBar.style.transform = `scaleX(${Math.min(Math.max(progress, 0), 1)})`;
  header.classList.toggle('scrolled', window.scrollY > 24);
}

updateScrollUI();
window.addEventListener('scroll', updateScrollUI, { passive: true });

function closeMenu() {
  menuToggle.setAttribute('aria-expanded', 'false');
  menuToggle.setAttribute('aria-label', 'Open navigation');
  navigation.classList.remove('open');
}

menuToggle.addEventListener('click', () => {
  const willOpen = menuToggle.getAttribute('aria-expanded') !== 'true';
  menuToggle.setAttribute('aria-expanded', String(willOpen));
  menuToggle.setAttribute('aria-label', willOpen ? 'Close navigation' : 'Open navigation');
  navigation.classList.toggle('open', willOpen);
});

navigation.querySelectorAll('a').forEach((link) => link.addEventListener('click', closeMenu));

document.addEventListener('click', (event) => {
  if (!navigation.contains(event.target) && !menuToggle.contains(event.target)) closeMenu();
});

filterButtons.forEach((button) => {
  button.addEventListener('click', () => {
    const filter = button.dataset.filter;
    let visibleCount = 0;

    filterButtons.forEach((item) => {
      const selected = item === button;
      item.classList.toggle('active', selected);
      item.setAttribute('aria-pressed', String(selected));
    });

    serviceCards.forEach((card) => {
      const groups = card.dataset.group.split(' ');
      const isVisible = filter === 'all' || groups.includes(filter);
      card.hidden = !isVisible;
      if (isVisible) visibleCount += 1;
    });

    const label = button.textContent.trim().toLowerCase();
    filterStatus.textContent = filter === 'all'
      ? `Showing all ${visibleCount} services`
      : `Showing ${visibleCount} services for ${label}`;
  });
});

function openInquiry(service = 'General consultation') {
  const optionExists = [...serviceSelect.options].some((option) => option.value === service);
  serviceSelect.value = optionExists ? service : 'General consultation';
  document.body.classList.add('modal-open');
  dialog.showModal();
}

function closeInquiry() {
  dialog.close();
}

document.querySelectorAll('[data-open-inquiry]').forEach((button) => {
  button.addEventListener('click', () => openInquiry(button.dataset.service));
});

document.querySelector('[data-close-inquiry]').addEventListener('click', closeInquiry);

dialog.addEventListener('click', (event) => {
  if (event.target === dialog) closeInquiry();
});

dialog.addEventListener('close', () => document.body.classList.remove('modal-open'));

inquiryForm.addEventListener('submit', (event) => {
  event.preventDefault();
  if (!inquiryForm.reportValidity()) return;

  const formData = new FormData(inquiryForm);
  const name = formData.get('name').trim();
  const phone = formData.get('phone').trim();
  const service = formData.get('service');
  const message = formData.get('message').trim() || 'Please contact me to discuss this requirement.';
  const subject = `Consultation request: ${service}`;
  const body = [
    `Hello Ramesh,`,
    '',
    `I would like to enquire about ${service}.`,
    '',
    `Name: ${name}`,
    `Mobile: ${phone}`,
    `Requirement: ${message}`,
    '',
    'Thank you.'
  ].join('\n');

  closeInquiry();
  showToast('Opening your email app with the enquiry ready.');
  window.location.href = `mailto:rameshkrishnaiyertx@gmail.com?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
});

let toastTimer;
function showToast(message) {
  clearTimeout(toastTimer);
  toast.textContent = message;
  toast.classList.add('visible');
  toastTimer = setTimeout(() => toast.classList.remove('visible'), 3200);
}

if (!reduceMotion && 'IntersectionObserver' in window) {
  document.documentElement.classList.add('reveal-ready');
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        }
      });
    },
    { threshold: 0.12, rootMargin: '0px 0px -30px' }
  );

  document.querySelectorAll('.reveal').forEach((element) => observer.observe(element));
}

const tiltArea = document.querySelector('[data-tilt-area]');
const tiltCard = document.querySelector('[data-tilt-card]');
const finePointer = window.matchMedia('(pointer: fine)').matches;

if (!reduceMotion && finePointer) {
  tiltArea.addEventListener('pointermove', (event) => {
    const bounds = tiltArea.getBoundingClientRect();
    const x = (event.clientX - bounds.left) / bounds.width - 0.5;
    const y = (event.clientY - bounds.top) / bounds.height - 0.5;
    tiltCard.style.setProperty('--tilt-x', `${-y * 7}deg`);
    tiltCard.style.setProperty('--tilt-y', `${x * 9}deg`);
  });

  tiltArea.addEventListener('pointerleave', () => {
    tiltCard.style.setProperty('--tilt-x', '0deg');
    tiltCard.style.setProperty('--tilt-y', '0deg');
  });
}
