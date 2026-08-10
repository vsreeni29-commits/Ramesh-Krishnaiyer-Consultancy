const header = document.querySelector('[data-header]');
const progressBar = document.querySelector('.scroll-progress span');
const menuToggle = document.querySelector('[data-menu-toggle]');
const navigation = document.querySelector('[data-navigation]');
const dialog = document.querySelector('#inquiry-dialog');
const inquiryForm = document.querySelector('[data-inquiry-form]');
const serviceSelect = document.querySelector('[data-service-select]');
const serviceAreaLabel = document.querySelector('[data-service-area-label]');
const serviceAreaInput = document.querySelector('[data-service-area-input]');
const serviceHelp = document.querySelector('[data-service-help]');
const dialogIntro = document.querySelector('[data-dialog-intro]');
const toast = document.querySelector('[data-toast]');
const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

const serviceCatalog = Object.freeze({
  "Income Tax": [
    "General Consultation",
    "TDS Returns e-Filing",
    "Advance Tax",
    "ITR1 (For Resident Individuals)",
    "ITR2 (For Residents & Individuals)",
    "ITR3 (For Residents & Individuals with Income from Business)",
    "ITR4 (For Residents, Individuals & Firms with Income from Business)",
    "ITR5 (For Non-Residents, Individuals, Partnership Firms, LLP & AOPs)",
    "ITR6 (For Registered Co., Tax Exempt u/Sec. 11)",
    "ITR7 (For Trusts, Charities & Educational Institutions)"
  ],
  "GST": [
    "General Consultation",
    "New Registration",
    "GSTR1 (For Monthly & Quarterly e-Filing)",
    "GSTR3B (Summary of GST Input/Output Tax Reconciliation & e-Filing)",
    "GSTR4 (For Registered Business Taxpayers - Half-yearly/Annual e-Filing)",
    "GSTR5 (For Non-Resident Business GST Tax e-Filing)",
    "GSTR6 (For Business Taxpayers - ITC Distribution Reconciliation & e-Filing)",
    "GSTR7 (For Business TDS under GST Deductions & Refunds e-Filing)",
    "GSTR8 (For E-Commerce Traders - TCS Reconciliation & e-Filing)",
    "GSTR9 (For GST Registered Businesses - Annual Statement Summary & e-Filing)",
    "GSTR10 (For Cancellation/Surrender of Existing GST Number)",
    "CMP4 (For GST Taxpayers - Composition Tax Reconciliation & e-Filing)",
    "ITC04 (For Business Taxpayers - Quarterly Returns under Capital Goods ITC)"
  ],
  "Professional Tax": [
    "General Consultation",
    "Professional Tax Deduction/Collection Certificate (Companies, Firms or Corporations)",
    "Professional Tax Enrolment Certificate (Individuals, Business Owners & Sole Proprietors)",
    "Professional Tax Workings & e-Filing"
  ],
  "EPF & ESIC": [
    "General Consultation",
    "Online Registration Process",
    "EPF Monthly Combined Challan A/c 1, 2, 10, 21 & 22 Workings & e-Filing",
    "ESIC Monthly Contribution Workings & e-Filing",
    "EPF & ESIC Half-yearly & Annual Returns Process & e-Filing",
    "EPF & ESIC Notification/Notice Management & Issue Resolution"
  ],
  "Book Keeping & Finalisation of Accounts": [
    "General Consultation",
    "Maintaining and Recording All Financial Transactions",
    "Day-to-day Financial Activities and Transactions",
    "Interpreting, Analysing, Summarising & Reporting Financial Transactions",
    "Preparation of Financial Reports and Statements for Audit Finalisation",
    "Internal Audit"
  ],
  "Other Workings & Process": [
    "FSSAI Registration as per Shop Act",
    "Udyam/Aadhaar (MSME/SSI Registration)",
    "TDS Returns & e-Filing",
    "PAN/TAN Application Process",
    "All kinds of Document Preparations and Online Registration"
  ]
});

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

function renderServiceOptions(serviceArea) {
  serviceSelect.replaceChildren();

  const placeholder = document.createElement('option');
  placeholder.value = '';
  placeholder.textContent = serviceArea === 'all'
    ? 'Choose a service'
    : `Choose a ${serviceArea} service`;
  placeholder.disabled = true;
  placeholder.selected = true;
  serviceSelect.append(placeholder);

  const serviceAreas = serviceArea === 'all' ? Object.keys(serviceCatalog) : [serviceArea];

  serviceAreas.forEach((area) => {
    const container = serviceArea === 'all' ? document.createElement('optgroup') : document.createDocumentFragment();
    if (serviceArea === 'all') container.label = area;

    serviceCatalog[area].forEach((serviceItem) => {
      const option = document.createElement('option');
      option.value = serviceItem;
      option.textContent = serviceItem;
      option.dataset.serviceArea = area;
      container.append(option);
    });

    serviceSelect.append(container);
  });

  const optionCount = serviceAreas.reduce((total, area) => total + serviceCatalog[area].length, 0);
  serviceHelp.textContent = serviceArea === 'all'
    ? `All ${optionCount} choices are grouped by service area.`
    : `Showing ${optionCount} choices for ${serviceArea}.`;
}

let activeServiceArea = 'all';

function openInquiry(serviceArea = 'all') {
  activeServiceArea = Object.hasOwn(serviceCatalog, serviceArea) ? serviceArea : 'all';
  inquiryForm.reset();
  serviceAreaInput.value = activeServiceArea === 'all' ? '' : activeServiceArea;
  serviceAreaLabel.textContent = activeServiceArea === 'all' ? 'All service areas' : activeServiceArea;
  dialogIntro.textContent = activeServiceArea === 'all'
    ? 'Browse all choices grouped by service area, then prepare your email.'
    : `Choose the exact requirement under ${activeServiceArea}, then prepare your email.`;
  renderServiceOptions(activeServiceArea);
  document.body.classList.add('modal-open');
  dialog.showModal();
}

function closeInquiry() {
  dialog.close();
}

document.querySelectorAll('[data-open-inquiry]').forEach((button) => {
  button.addEventListener('click', () => openInquiry(button.dataset.serviceArea));
});

serviceSelect.addEventListener('change', () => {
  const selectedOption = serviceSelect.selectedOptions[0];
  if (!selectedOption) return;

  const selectedArea = selectedOption.dataset.serviceArea || activeServiceArea;
  serviceAreaInput.value = selectedArea;
  if (activeServiceArea === 'all') serviceAreaLabel.textContent = selectedArea;
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
  const serviceArea = formData.get('serviceArea').trim();
  const serviceItem = formData.get('serviceItem').trim();
  const message = formData.get('message').trim() || 'Please contact me to discuss this requirement.';
  const subject = `Consultation request: ${serviceArea} - ${serviceItem}`;
  const body = [
    `Hello Ramesh,`,
    '',
    `I would like to enquire about ${serviceItem} under ${serviceArea}.`,
    '',
    `Name: ${name}`,
    `Mobile: ${phone}`,
    `Service area: ${serviceArea}`,
    `Selected service: ${serviceItem}`,
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
