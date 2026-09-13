/// Every user-facing string, in English and Bangla.
///
/// Each key must supply both languages (enforced by the constructor), and a test
/// verifies both use the same `{placeholders}`. Widgets never hardcode copy;
/// they call `context.s(T.key)` (see locale_scope.dart).
enum T {
  // ── General ──────────────────────────────────────────────────────────
  appName('Sanket', 'সংকেত'),
  tagline('Early developmental signals,\nnot diagnoses.', 'প্রাথমিক বিকাশের সংকেত,\nরোগনির্ণয় নয়।'),
  continueLabel('Continue', 'এগিয়ে যান'),
  back('Back', 'পেছনে'),
  cancel('Cancel', 'বাতিল'),
  tryAgain('Try again', 'আবার চেষ্টা করুন'),
  yes('Yes', 'হ্যাঁ'),
  no('No', 'না'),
  switchLanguage('বাংলা', 'English'),
  reward('Well done!', 'দারুণ!'),
  guideName('Mitu', 'মিতু'),

  // ── Welcome ──────────────────────────────────────────────────────────
  welcomeLead(
      'Sanket uses short guided activities to observe selected developmental behaviours. It does not diagnose autism or any other condition.',
      'সংকেত ছোট ছোট নির্দেশিত খেলার মাধ্যমে শিশুর নির্দিষ্ট কিছু বিকাশমূলক আচরণ পর্যবেক্ষণ করে। এটি অটিজম বা অন্য কোনো অবস্থার রোগনির্ণয় করে না।'),
  welcomeDuration('About 6–8 minutes · for children 18–36 months', 'প্রায় ৬–৮ মিনিট · ১৮–৩৬ মাস বয়সী শিশুদের জন্য'),
  welcomeStart('Start a guided session', 'নির্দেশিত সেশন শুরু করুন'),
  welcomeHistory('Previous sessions', 'আগের সেশনগুলো'),
  welcomePrivacy(
      'Everything is processed on this phone. No video or audio is recorded, and Sanket never gives a diagnosis.',
      'সবকিছু এই ফোনেই প্রক্রিয়া করা হয়। কোনো ভিডিও বা অডিও রেকর্ড করা হয় না, এবং সংকেত কখনো রোগনির্ণয় দেয় না।'),
  welcomeCompanionLabel('Sanket’s friendly green bird holding a star', 'তারা হাতে সংকেতের বন্ধু সবুজ পাখি'),

  // ── Consent ──────────────────────────────────────────────────────────
  consentOverline('Before we begin', 'শুরু করার আগে'),
  consentTitle('What Sanket can and cannot do', 'সংকেত কী পারে আর কী পারে না'),
  canLabel('It can', 'এটি পারে'),
  cannotLabel('It cannot', 'এটি পারে না'),
  consentCan(
      'Guide short play activities and summarise the observations that passed quality checks.',
      'ছোট খেলার কার্যক্রম পরিচালনা করতে এবং মান যাচাইয়ে উত্তীর্ণ পর্যবেক্ষণগুলোর সারাংশ দিতে।'),
  consentCannot(
      'Diagnose autism or any developmental condition, replace a professional, or give treatment advice.',
      'অটিজম বা কোনো বিকাশজনিত অবস্থার রোগনির্ণয় করতে, বিশেষজ্ঞের বিকল্প হতে বা চিকিৎসার পরামর্শ দিতে।'),
  consentChoose('Your choices', 'আপনার সিদ্ধান্ত'),
  consentRequired('Required', 'আবশ্যক'),
  consentOptional('Optional', 'ঐচ্ছিক'),
  consentProcessingTitle('Use the camera and microphone during this session', 'এই সেশনে ক্যামেরা ও মাইক্রোফোন ব্যবহার করুন'),
  consentProcessingBody(
      'Head movement, body position and sound level are measured on this phone while activities run. Nothing is recorded.',
      'কার্যক্রম চলার সময় মাথার নড়াচড়া, শরীরের অবস্থান ও শব্দের মাত্রা এই ফোনেই মাপা হয়। কিছুই রেকর্ড করা হয় না।'),
  consentStoreTitle('Save session summaries on this phone', 'সেশনের সারাংশ এই ফোনে সংরক্ষণ করুন'),
  consentStoreBody(
      'Keeps measurements (never video or audio) so you can see sessions over time. You can delete them at any time.',
      'মাপা তথ্য (কখনো ভিডিও বা অডিও নয়) রাখা হয়, যাতে সময়ের সাথে সেশনগুলো দেখতে পারেন। যেকোনো সময় মুছে ফেলা যায়।'),
  consentShareTitle('Allow sharing the summary with a professional later', 'পরে কোনো বিশেষজ্ঞের সাথে সারাংশ শেয়ার করার অনুমতি দিন'),
  consentShareBody(
      'This version does not send anything. Your choice is saved, and you will be asked again before anything is shared.',
      'এই সংস্করণ কিছুই পাঠায় না। আপনার সিদ্ধান্ত সংরক্ষিত থাকবে, আর কিছু শেয়ার করার আগে আবার জিজ্ঞেস করা হবে।'),
  consentResearchTitle('Allow separate research use of de-identified measurements', 'পরিচয়হীন মাপা তথ্য আলাদাভাবে গবেষণায় ব্যবহারের অনুমতি দিন'),
  consentResearchBody(
      'Completely separate from your session result. This version does not send anything.',
      'এটি আপনার সেশনের ফলাফল থেকে সম্পূর্ণ আলাদা। এই সংস্করণ কিছুই পাঠায় না।'),
  consentNever(
      'Never: facial identity recognition, background recording, or keeping raw video or audio. You can stop at any time.',
      'কখনোই না: মুখ দেখে পরিচয় শনাক্ত করা, পটভূমিতে রেকর্ডিং, বা মূল ভিডিও-অডিও রেখে দেওয়া। আপনি যেকোনো সময় থামাতে পারেন।'),
  consentAgree('I understand and agree', 'আমি বুঝেছি এবং সম্মত'),
  consentNeedProcessing('Camera and microphone use is required to run the activities.', 'কার্যক্রম চালাতে ক্যামেরা ও মাইক্রোফোন ব্যবহারের অনুমতি প্রয়োজন।'),

  // ── Profile ──────────────────────────────────────────────────────────
  profileOverline('Baseline context', 'প্রাথমিক তথ্য'),
  profileTitle('Tell us about your child', 'আপনার শিশুর সম্পর্কে বলুন'),
  profileLead('This helps interpret the observations carefully.', 'এতে পর্যবেক্ষণগুলো সতর্কভাবে বোঝা সহজ হয়।'),
  profileName('Familiar name or nickname', 'ডাকনাম'),
  profileNameHelp('You will call this name out loud during one activity.', 'একটি কার্যক্রমে আপনি এই নাম ধরে ডাকবেন।'),
  profileNameMissing('Please enter the name you call your child.', 'শিশুকে যে নামে ডাকেন, সেটি লিখুন।'),
  profileAge('Age in months', 'বয়স (মাসে)'),
  profileAgeInvalid('Sanket is designed for children aged 18–36 months.', 'সংকেত ১৮–৩৬ মাস বয়সী শিশুদের জন্য তৈরি।'),
  profilePrimaryLanguage('Language spoken most at home', 'বাড়িতে সবচেয়ে বেশি বলা ভাষা'),
  profileOtherLanguage('Other language exposure', 'অন্য ভাষার সংস্পর্শ'),
  langBangla('Bangla', 'বাংলা'),
  langEnglish('English', 'ইংরেজি'),
  langBoth('Both', 'দুটোই'),
  langNone('None', 'নেই'),
  langOther('Other', 'অন্য'),
  profileHearing('Any known hearing concern?', 'শোনার কোনো জানা সমস্যা আছে?'),
  profileVision('Any known vision concern?', 'দেখার কোনো জানা সমস্যা আছে?'),
  profileMotor('Any known difficulty moving hands or body?', 'হাত বা শরীর নাড়াতে কোনো জানা অসুবিধা আছে?'),
  profilePriorConcern('Has anyone raised a developmental concern before?', 'আগে কেউ কি বিকাশ নিয়ে কোনো উদ্বেগ জানিয়েছেন?'),
  profileScreen('How used to touchscreens is your child?', 'শিশু টাচস্ক্রিনে কতটা অভ্যস্ত?'),
  screenLow('Rarely', 'কম'),
  screenMedium('Sometimes', 'মাঝে মাঝে'),
  screenHigh('Often', 'প্রায়ই'),
  profileContextNote(
      'These answers do not change the activities. They stop Sanket from over-interpreting an activity that a known concern could affect.',
      'এই উত্তরগুলো কার্যক্রম বদলায় না। কোনো জানা সমস্যা যে কার্যক্রমকে প্রভাবিত করতে পারে, সেটির অতিরিক্ত ব্যাখ্যা এড়াতে সাহায্য করে।'),
  profileUnder24Note(
      'At this age there are five activities. “Switch It” begins at 24 months.',
      'এই বয়সে পাঁচটি কার্যক্রম থাকবে। “বদলে দাও” শুরু হয় ২৪ মাস থেকে।'),

  // ── Setup check ──────────────────────────────────────────────────────
  setupOverline('Get ready', 'প্রস্তুতি'),
  setupTitle('Let’s set up a calm space', 'চলুন একটি শান্ত জায়গা ঠিক করি'),
  setupLead(
      'Sit with {name} somewhere quiet with soft, even light. Stand the phone sideways on a stable surface, about an arm’s length away.',
      '{name}-কে নিয়ে নরম, সমান আলোর কোনো শান্ত জায়গায় বসুন। ফোনটি আড়াআড়ি করে প্রায় এক হাত দূরে কোনো স্থির জায়গায় দাঁড় করিয়ে রাখুন।'),
  setupPermissionTitle('Camera and microphone access', 'ক্যামেরা ও মাইক্রোফোনের অনুমতি'),
  setupPermissionBody(
      'Android will ask for permission. The camera measures head and body movement. The microphone measures only loudness, so Sanket can tell when you call {name}.',
      'অ্যান্ড্রয়েড অনুমতি চাইবে। ক্যামেরা মাথা ও শরীরের নড়াচড়া মাপে। মাইক্রোফোন শুধু শব্দের মাত্রা মাপে, যাতে বোঝা যায় কখন আপনি {name}-কে ডাকছেন।'),
  setupAllow('Allow access', 'অনুমতি দিন'),
  setupOpenSettings('Open phone settings', 'ফোনের সেটিংস খুলুন'),
  setupCameraDenied(
      'Camera access was not allowed. Activities that need the camera will be marked as not measured.',
      'ক্যামেরার অনুমতি দেওয়া হয়নি। যেসব কার্যক্রমে ক্যামেরা লাগে, সেগুলো “মাপা হয়নি” হিসেবে দেখানো হবে।'),
  setupMicDenied(
      'Microphone access was not allowed. You will tap a button as you call {name}, so timing will be less precise.',
      'মাইক্রোফোনের অনুমতি দেওয়া হয়নি। {name}-কে ডাকার সময় আপনি একটি বোতাম চাপবেন, তাই সময়ের হিসাব কম নিখুঁত হবে।'),
  setupChecksTitle('Live check', 'সরাসরি যাচাই'),
  checkCamera('Camera', 'ক্যামেরা'),
  checkLighting('Lighting', 'আলো'),
  checkFace('Face in view', 'মুখ দেখা যাচ্ছে'),
  checkQuiet('Background noise', 'আশপাশের শব্দ'),
  checkTouch('Touchscreen', 'টাচস্ক্রিন'),
  statusGood('Good', 'ভালো'),
  statusChecking('Checking…', 'যাচাই হচ্ছে…'),
  statusUnavailable('Not available', 'পাওয়া যাচ্ছে না'),
  statusTooDark('Too dark', 'খুব অন্ধকার'),
  statusTooBright('Too bright', 'খুব উজ্জ্বল'),
  statusNoFace('Not visible', 'দেখা যাচ্ছে না'),
  statusTooFar('Too far', 'খুব দূরে'),
  statusTooClose('Too close', 'খুব কাছে'),
  statusNoisy('Noisy', 'শব্দ বেশি'),
  statusSlow('Too slow', 'খুব ধীর'),
  setupTipFace('Keep {name}’s face inside the preview.', '{name}-এর মুখ প্রিভিউয়ের মধ্যে রাখুন।'),
  setupContinueAnyway(
      'Some checks are not good yet. You can still begin — anything unreliable will be left out, never guessed.',
      'কিছু যাচাই এখনো ভালো নয়। তবুও শুরু করতে পারেন — অনির্ভরযোগ্য কিছু থাকলে তা বাদ দেওয়া হবে, কখনো অনুমান করা হবে না।'),
  setupBegin('Begin activities', 'কার্যক্রম শুরু করুন'),
  setupRotateHint('The screen turns sideways for the activities.', 'কার্যক্রমের জন্য স্ক্রিন আড়াআড়ি হয়ে যাবে।'),

  // ── Session stage ────────────────────────────────────────────────────
  stageActivityOf('Activity {n} of {total}', 'কার্যক্রম {n} / {total}'),
  stageStop('End session', 'সেশন শেষ করুন'),
  stagePause('Pause', 'বিরতি'),
  stageResume('Resume', 'আবার শুরু'),
  stagePausedTitle('Paused', 'বিরতি চলছে'),
  stagePausedBody('This activity starts again from the beginning when you resume.', 'আবার শুরু করলে এই কার্যক্রম গোড়া থেকে শুরু হবে।'),
  stageStopTitle('End the session now?', 'এখনই সেশন শেষ করবেন?'),
  stageStopBody(
      'Completed activities are kept. The summary uses only what was reliably measured.',
      'যেসব কার্যক্রম শেষ হয়েছে সেগুলো থাকবে। সারাংশে শুধু নির্ভরযোগ্যভাবে মাপা তথ্যই ব্যবহার হবে।'),
  stageKeepGoing('Keep going', 'চালিয়ে যান'),
  stageWeObserve('We observe: {construct}', 'আমরা লক্ষ্য করি: {construct}'),
  stageStartActivity('Start activity', 'কার্যক্রম শুরু করুন'),
  stageSkipActivity('Skip', 'বাদ দিন'),
  stageMeasuring('Measuring…', 'মাপা হচ্ছে…'),
  stageNextActivity('Next activity', 'পরের কার্যক্রম'),
  stageSeeSummary('See session summary', 'সেশনের সারাংশ দেখুন'),
  stageTryOf('Try {n} of {total}', 'চেষ্টা {n} / {total}'),
  stageTimeLeft('{sec} s left', 'আর {sec} সেকেন্ড'),
  doneMeasured('Measured', 'মাপা হয়েছে'),
  doneNotEnough('Not enough reliable signal', 'যথেষ্ট নির্ভরযোগ্য তথ্য পাওয়া যায়নি'),
  doneNoParticipation('{name} didn’t join in this time — that’s okay.', '{name} এবার যোগ দেয়নি — এতে কোনো সমস্যা নেই।'),
  doneRetryOffer('You can try once more, or move on.', 'আরেকবার চেষ্টা করতে পারেন, অথবা এগিয়ে যেতে পারেন।'),
  doneValidTrials('{n} of {total} tries measured', '{total}টির মধ্যে {n}টি চেষ্টা মাপা গেছে'),
  breakTitle('{name} may need a break', '{name}-এর হয়তো বিরতি দরকার'),
  breakBody(
      'The last activities did not hold {name}’s interest. You can end now and try another day — nothing is lost.',
      'শেষ কার্যক্রমগুলোতে {name}-এর আগ্রহ ছিল না। এখন শেষ করে অন্য দিন চেষ্টা করতে পারেন — কিছুই হারাবে না।'),
  timeLimitTitle('Time limit reached', 'সময়সীমা শেষ'),
  timeLimitBody(
      'Sessions are kept short for children. The summary uses the activities completed so far.',
      'শিশুদের জন্য সেশন ছোট রাখা হয়। এখন পর্যন্ত শেষ হওয়া কার্যক্রম দিয়ে সারাংশ তৈরি হবে।'),
  needsCamera(
      'This activity needs the camera, which is not available. It will be marked as not measured.',
      'এই কার্যক্রমে ক্যামেরা লাগে, যা পাওয়া যাচ্ছে না। এটি “মাপা হয়নি” হিসেবে দেখানো হবে।'),
  parentOnly('For you', 'আপনার জন্য'),

  // ── Calibration ──────────────────────────────────────────────────────
  calTitle('Quick look check', 'দ্রুত দৃষ্টি যাচাই'),
  calParent(
      'Seat {name} comfortably facing the phone. A star moves to four places — let {name} watch it. Please don’t point.',
      '{name}-কে আরাম করে ফোনের দিকে মুখ করে বসান। একটি তারা চারটি জায়গায় যাবে — {name}-কে সেটি দেখতে দিন। আঙুল দিয়ে দেখাবেন না।'),
  calWhy('This checks whether head direction can be measured reliably in this setup.', 'এই অবস্থায় মাথার দিক নির্ভরযোগ্যভাবে মাপা যায় কি না, এটি তা যাচাই করে।'),
  calStart('Start look check', 'দৃষ্টি যাচাই শুরু করুন'),
  calWaitingFace('Waiting to see {name}’s face…', '{name}-এর মুখ দেখার অপেক্ষা…'),
  calRunning('Watch the star!', 'তারাটা দেখো!'),
  calUsable('Look direction can be measured', 'দৃষ্টির দিক মাপা যাবে'),
  calUsableBody('Clear left–right difference, steady measurement.', 'বাম-ডানের স্পষ্ট পার্থক্য, স্থির মাপ।'),
  calUnusable('Look direction can’t be measured reliably', 'দৃষ্টির দিক নির্ভরযোগ্যভাবে মাপা যাচ্ছে না'),
  calUnusableBody(
      'Activities that depend on where {name} looks will leave that measurement out.',
      '{name} কোথায় তাকায় তার ওপর নির্ভরশীল কার্যক্রমগুলোতে সেই মাপ বাদ থাকবে।'),
  calContinueWithout('Continue without look direction', 'দৃষ্টির দিক ছাড়াই এগিয়ে যান'),

  // ── Reasons ──────────────────────────────────────────────────────────
  rCameraUnavailable('The camera was not available.', 'ক্যামেরা পাওয়া যায়নি।'),
  rCameraPermissionDenied('Camera access was not allowed.', 'ক্যামেরার অনুমতি দেওয়া হয়নি।'),
  rLowFrameRate('The camera was too slow on this phone.', 'এই ফোনে ক্যামেরা খুব ধীর ছিল।'),
  rTooDark('It was too dark.', 'আলো খুব কম ছিল।'),
  rTooBright('The light was too bright or behind {name}.', 'আলো খুব বেশি ছিল বা {name}-এর পেছন থেকে আসছিল।'),
  rFaceNotVisible('{name}’s face was not visible enough.', '{name}-এর মুখ যথেষ্ট দেখা যায়নি।'),
  rFaceTooFar('{name} was too far from the phone.', '{name} ফোন থেকে খুব দূরে ছিল।'),
  rFaceTooClose('{name} was too close to the phone.', '{name} ফোনের খুব কাছে ছিল।'),
  rEyesNotVisible('{name}’s eyes were not visible enough.', '{name}-এর চোখ যথেষ্ট দেখা যায়নি।'),
  rGazeNotCalibrated('The look check was not completed.', 'দৃষ্টি যাচাই সম্পন্ন হয়নি।'),
  rGazeCalibrationUnusable('The look check did not pass.', 'দৃষ্টি যাচাই সফল হয়নি।'),
  rCalibrationTooFewSamples('{name}’s face was not seen clearly enough during the look check.', 'দৃষ্টি যাচাইয়ের সময় {name}-এর মুখ যথেষ্ট স্পষ্ট দেখা যায়নি।'),
  rCalibrationTargetsNotSeparable('Looking left and looking right could not be told apart.', 'বামে ও ডানে তাকানো আলাদা করা যায়নি।'),
  rCalibrationUnstable('Head position moved too much to measure.', 'মাথা খুব বেশি নড়ছিল, তাই মাপা যায়নি।'),
  rMicrophoneUnavailable('The microphone was not available.', 'মাইক্রোফোন পাওয়া যায়নি।'),
  rMicrophonePermissionDenied('Microphone access was not allowed.', 'মাইক্রোফোনের অনুমতি দেওয়া হয়নি।'),
  rTooNoisy('It was too noisy to time the call.', 'ডাকার সময় মাপার জন্য আশপাশে শব্দ বেশি ছিল।'),
  rCallNotDetected('The name call was not heard.', 'নাম ধরে ডাকা শোনা যায়নি।'),
  rCallTimedByCaregiver('Call timing came from your button tap, so it is less precise.', 'ডাকার সময় আপনার বোতাম চাপা থেকে নেওয়া, তাই কম নিখুঁত।'),
  rNotAttendingBeforePrompt('{name} was not watching the screen when the try began.', 'চেষ্টা শুরুর সময় {name} স্ক্রিনের দিকে তাকিয়ে ছিল না।'),
  rAlreadyLookingAtTarget('{name} was already looking at the toy before {guide} looked.', '{guide} তাকানোর আগেই {name} খেলনার দিকে তাকিয়ে ছিল।'),
  rFaceLostWithoutTurn('{name} moved out of view.', '{name} ক্যামেরার বাইরে চলে গিয়েছিল।'),
  rBodyNotVisible('{name}’s shoulders and hands were not in view.', '{name}-এর কাঁধ ও হাত দেখা যাচ্ছিল না।'),
  rTooFewTouches('Too few taps to measure.', 'মাপার মতো যথেষ্ট ট্যাপ হয়নি।'),
  rNoTouches('No taps.', 'কোনো ট্যাপ হয়নি।'),
  rPalmContact('Many touches looked like a palm or several fingers.', 'অনেক স্পর্শ হাতের তালু বা একাধিক আঙুলের মতো মনে হয়েছে।'),
  rTooFewResponses('Too few answers to measure.', 'মাপার মতো যথেষ্ট সাড়া পাওয়া যায়নি।'),
  rNoResponses('No answer in time.', 'সময়মতো সাড়া পাওয়া যায়নি।'),
  rTooFewValidTrials('Too few tries could be measured reliably.', 'খুব কম চেষ্টা নির্ভরযোগ্যভাবে মাপা গেছে।'),
  rPausedByCaregiver('Paused.', 'বিরতি দেওয়া হয়েছিল।'),
  rSkippedByCaregiver('Skipped by you.', 'আপনি বাদ দিয়েছেন।'),
  rStoppedEarly('The session ended before this activity finished.', 'এই কার্যক্রম শেষ হওয়ার আগেই সেশন শেষ হয়েছে।'),
  rNotOfferedForAge('Starts at 24 months.', '২৪ মাস বয়স থেকে শুরু হয়।'),
  rSessionTimeLimit('The session time limit was reached.', 'সেশনের সময়সীমা শেষ হয়েছিল।'),
  rNoParticipation('{name} didn’t join in.', '{name} যোগ দেয়নি।'),

  // ── Activity statuses ────────────────────────────────────────────────
  aValid('Measured', 'মাপা হয়েছে'),
  aInsufficient('Not enough reliable signal', 'যথেষ্ট নির্ভরযোগ্য তথ্য নেই'),
  aNonParticipation('Didn’t join in', 'যোগ দেয়নি'),
  aSkipped('Skipped', 'বাদ দেওয়া হয়েছে'),
  aNotOffered('Not offered at this age', 'এই বয়সে প্রযোজ্য নয়'),

  // ── Social Story ─────────────────────────────────────────────────────
  storyName('Social Story', 'গল্পের সময়'),
  storyConstruct('Social attention', 'সামাজিক মনোযোগ'),
  storyParent(
      'Sit beside {name} and watch together quietly. Please don’t point at the screen.',
      '{name}-এর পাশে বসে চুপচাপ একসাথে দেখুন। স্ক্রিনের দিকে আঙুল দিয়ে দেখাবেন না।'),
  storyChild('Let’s watch!', 'চলো দেখি!'),
  storyLine1('Hello! I’m {guide}!', 'হ্যালো! আমি {guide}!'),
  storyLine2('Look, I’m waving at you!', 'দেখো, আমি তোমার দিকে হাত নাড়ছি!'),
  storyLine3('Can you see me smile?', 'আমার হাসি দেখছ?'),
  storyLine4('Let’s play together!', 'চলো একসাথে খেলি!'),
  storyLookAway(
      '{name} is looking away. Gently bring {name}’s attention back to the phone — without pointing.',
      '{name} অন্যদিকে তাকাচ্ছে। আঙুল না দেখিয়ে আলতো করে {name}-এর মনোযোগ ফোনের দিকে ফেরান।'),

  // ── Name Response ────────────────────────────────────────────────────
  nameName('Name Response', 'নাম ধরে ডাকা'),
  nameConstruct('Social orienting', 'ডাকে সাড়া দেওয়া'),
  nameParent(
      'Sit slightly behind {name}, to one side. When the banner asks, call “{name}” once in your normal voice — then stay quiet.',
      '{name}-এর একটু পেছনে, এক পাশে বসুন। ব্যানারে বললে স্বাভাবিক গলায় একবার “{name}” বলে ডাকুন — তারপর চুপ থাকুন।'),
  nameWaitAttention('Stay quiet — waiting for {name} to watch the screen…', 'চুপ থাকুন — {name} স্ক্রিনের দিকে তাকানোর অপেক্ষা…'),
  nameCallNow('Now call “{name}” once', 'এখন একবার “{name}” বলে ডাকুন'),
  nameHeard('Heard you — stay quiet', 'শোনা গেছে — চুপ থাকুন'),
  nameICalled('I called {name}', 'আমি {name}-কে ডেকেছি'),
  nameTapFallback('Tap this button at the moment you call.', 'যখন ডাকবেন, ঠিক তখনই এই বোতামটি চাপুন।'),
  nameNotHeard('The call wasn’t heard. The next try starts in a moment.', 'ডাকটি শোনা যায়নি। একটু পরেই পরের চেষ্টা শুরু হবে।'),
  nameBetween('Nice. Next try in a moment…', 'ভালো। একটু পরেই পরের চেষ্টা…'),
  nameChild('Look at the stars!', 'তারাগুলো দেখো!'),

  // ── Follow My Look ───────────────────────────────────────────────────
  lookName('Follow My Look', 'আমার চোখ অনুসরণ করো'),
  lookConstruct('Joint attention', 'যৌথ মনোযোগ'),
  lookParent(
      'Stay quiet and let {name} watch. {guide} will look at one of the toys. Please don’t point or name the toys.',
      'চুপ থাকুন আর {name}-কে দেখতে দিন। {guide} একটি খেলনার দিকে তাকাবে। খেলনার দিকে দেখাবেন না বা নাম বলবেন না।'),
  lookChild('Where is {guide} looking?', '{guide} কোথায় তাকাচ্ছে?'),
  lookWaitCenter('Waiting for {name} to look at {guide}…', '{name} {guide}-এর দিকে তাকানোর অপেক্ষা…'),
  lookToyCar('Toy car', 'খেলনা গাড়ি'),
  lookToyBunny('Toy bunny', 'খেলনা খরগোশ'),
  lookGazeUnavailable(
      'Look direction isn’t available in this setup, so only which toy {name} taps will be noted.',
      'এই অবস্থায় দৃষ্টির দিক মাপা যাচ্ছে না, তাই শুধু {name} কোন খেলনায় ট্যাপ করে তা লেখা হবে।'),

  // ── Bubble Trail ─────────────────────────────────────────────────────
  bubbleName('Bubble Trail', 'বুদবুদের খেলা'),
  bubbleConstruct('Visual-motor interaction', 'চোখ ও হাতের সমন্বয়'),
  bubbleParent(
      'Let {name} tap the bubbles with one finger. You may show one tap first, then let {name} play alone.',
      '{name}-কে এক আঙুল দিয়ে বুদবুদ ফাটাতে দিন। প্রথমে একবার দেখিয়ে দিতে পারেন, তারপর {name}-কে একা খেলতে দিন।'),
  bubbleChild('Pop the bubbles!', 'বুদবুদ ফাটাও!'),
  bubbleInactive('Show {name} one tap, then let {name} try.', '{name}-কে একবার ট্যাপ করে দেখান, তারপর নিজে চেষ্টা করতে দিন।'),
  bubblePopped('{n} popped', '{n}টি ফেটেছে'),

  // ── Copy Me ──────────────────────────────────────────────────────────
  copyName('Copy Me', 'আমার মতো করো'),
  copyConstruct('Imitation', 'অনুকরণ'),
  copyParent(
      'Seat {name} facing the phone with shoulders and hands in view. {guide} shows a movement — let {name} copy. Please don’t do the movement yourself.',
      '{name}-কে ফোনের দিকে মুখ করে বসান, যাতে কাঁধ ও হাত দেখা যায়। {guide} একটি ভঙ্গি দেখাবে — {name}-কে নকল করতে দিন। নিজে ভঙ্গিটি করবেন না।'),
  copyFraming('Move the phone back a little so {name}’s shoulders and hands are visible.', 'ফোনটি একটু পিছিয়ে নিন, যাতে {name}-এর কাঁধ ও হাত দেখা যায়।'),
  copyWatch('Watch {guide}!', '{guide}-কে দেখো!'),
  copyYourTurn('Your turn!', 'এবার তোমার পালা!'),
  copyHandsUp('Hands up!', 'হাত ওপরে!'),
  copyClap('Clap your hands!', 'হাততালি দাও!'),
  copyTouchHead('Touch your head!', 'মাথায় হাত দাও!'),
  copySeen('Movement seen', 'ভঙ্গি দেখা গেছে'),

  // ── Switch It ────────────────────────────────────────────────────────
  switchName('Switch It', 'বদলে দাও'),
  switchConstruct('Attention shifting', 'মনোযোগ বদলানো'),
  switchParent(
      'Let {name} tap without help. First the game asks for the bird, then it switches to the ball. Please don’t show which one to tap.',
      '{name}-কে সাহায্য ছাড়া ট্যাপ করতে দিন। প্রথমে পাখি, পরে বল বেছে নিতে বলা হবে। কোনটি চাপতে হবে দেখিয়ে দেবেন না।'),
  switchTapBird('Tap the bird!', 'পাখিটায় ট্যাপ করো!'),
  switchTapBall('Tap the ball!', 'বলটায় ট্যাপ করো!'),
  switchNow('New game — now the ball!', 'নতুন খেলা — এবার বল!'),

  // ── Result ───────────────────────────────────────────────────────────
  resultOverline('Session summary', 'সেশনের সারাংশ'),
  stateNoStrongTitle('No strong follow-up signal observed', 'ফলো-আপের জোরালো কোনো সংকেত দেখা যায়নি'),
  stateNoStrongBody(
      'No consistent pattern requiring escalation was observed in this session. This does not rule out a developmental condition.',
      'এই সেশনে উদ্বেগ বাড়ানোর মতো কোনো ধারাবাহিক ধরন দেখা যায়নি। এর মানে এই নয় যে কোনো বিকাশজনিত অবস্থা থাকতে পারে না।'),
  stateMonitorTitle('Monitor', 'নজর রাখুন'),
  stateMonitorBody('One or more observations may be worth monitoring over time.', 'এক বা একাধিক পর্যবেক্ষণ সময়ের সাথে নজরে রাখা যেতে পারে।'),
  stateDiscussTitle('Discuss with a professional', 'একজন বিশেষজ্ঞের সাথে আলোচনা করুন'),
  stateDiscussBody('Several observations may be worth discussing with a qualified professional.', 'কয়েকটি পর্যবেক্ষণ নিয়ে একজন যোগ্য বিশেষজ্ঞের সাথে আলোচনা করা যেতে পারে।'),
  stateInconclusiveTitle('Inconclusive', 'নিশ্চিত বলা যাচ্ছে না'),
  stateInconclusiveBody(
      'Sanket could not reliably interpret this session. {name} did not fail anything.',
      'সংকেত এই সেশনটি নির্ভরযোগ্যভাবে ব্যাখ্যা করতে পারেনি। {name} কোনো কিছুতে ব্যর্থ হয়নি।'),
  nextNoStrong(
      'Keep enjoying everyday play. If you have a concern at any time, talk to a qualified professional — your observations matter.',
      'প্রতিদিনের খেলা উপভোগ করুন। যেকোনো সময় উদ্বেগ হলে একজন যোগ্য বিশেষজ্ঞের সাথে কথা বলুন — আপনার পর্যবেক্ষণ গুরুত্বপূর্ণ।'),
  nextMonitor(
      'Keep noticing these moments in everyday life. You can repeat a session later to see whether the same pattern appears, and mention it at {name}’s next health visit.',
      'প্রতিদিনের জীবনে এই মুহূর্তগুলো লক্ষ্য করুন। একই ধরন আবার দেখা যায় কি না জানতে পরে আবার সেশন করতে পারেন, এবং {name}-এর পরের স্বাস্থ্য পরীক্ষায় বিষয়টি জানান।'),
  nextDiscuss(
      'Consider sharing this summary with a paediatrician or a Child Development Centre. Only a qualified professional can assess {name}’s development.',
      'এই সারাংশটি একজন শিশু বিশেষজ্ঞ বা শিশু বিকাশ কেন্দ্রের সাথে শেয়ার করার কথা ভাবুন। শুধু একজন যোগ্য বিশেষজ্ঞই {name}-এর বিকাশ মূল্যায়ন করতে পারেন।'),
  nextInconclusive(
      'Try another day in a quiet, well-lit place when {name} is rested.',
      '{name} বিশ্রাম নেওয়ার পর কোনো শান্ত, আলোকিত জায়গায় অন্য দিন আবার চেষ্টা করুন।'),
  inconclusiveTooFew('Only {n} activities had enough reliable measurement.', 'মাত্র {n}টি কার্যক্রমে যথেষ্ট নির্ভরযোগ্য মাপ পাওয়া গেছে।'),
  inconclusiveEvidence(
      'Too few of the core activities (Social Story, Name Response, Follow My Look) could be measured.',
      'মূল কার্যক্রমগুলোর (গল্পের সময়, নাম ধরে ডাকা, আমার চোখ অনুসরণ করো) খুব কমই মাপা গেছে।'),
  resultWhatObserved('What was observed', 'যা পর্যবেক্ষণ করা হয়েছে'),
  resultNextStep('Next step', 'পরবর্তী পদক্ষেপ'),
  resultBoundary(
      'Sanket is a research prototype. It describes behaviour in one session using prototype rules that are not clinically validated. It is not a diagnosis.',
      'সংকেত একটি গবেষণা প্রোটোটাইপ। এটি ক্লিনিক্যালি যাচাই না করা প্রোটোটাইপ নিয়মে একটি সেশনের আচরণ বর্ণনা করে। এটি রোগনির্ণয় নয়।'),
  resultCopy('Copy summary', 'সারাংশ কপি করুন'),
  resultCopied('Summary copied.', 'সারাংশ কপি হয়েছে।'),
  resultSaved('Saved on this phone', 'এই ফোনে সংরক্ষিত'),
  resultSaving('Saving…', 'সংরক্ষণ হচ্ছে…'),
  resultNotSaved('Not saved — you chose not to keep sessions.', 'সংরক্ষিত হয়নি — আপনি সেশন না রাখার সিদ্ধান্ত নিয়েছেন।'),
  resultHistory('View session history', 'সেশনের ইতিহাস দেখুন'),
  resultHome('Return home', 'হোমে ফিরুন'),
  resultPatternSuppressed('Not interpreted, because a {factor} was reported.', '{factor} জানানো হয়েছে বলে ব্যাখ্যা করা হয়নি।'),
  resultDescriptiveOnly('Described only — this activity does not change the next step.', 'শুধু বর্ণনা — এই কার্যক্রম পরবর্তী পদক্ষেপ বদলায় না।'),
  factorHearing('hearing concern', 'শোনার সমস্যা'),
  factorVision('vision concern', 'দেখার সমস্যা'),
  factorMotor('motor difficulty', 'নড়াচড়ার অসুবিধা'),
  noteStory(
      '{name} looked more at the turning toy than at {guide} in both parts of the story.',
      'গল্পের দুই অংশেই {name} {guide}-এর চেয়ে ঘুরতে থাকা খেলনার দিকে বেশি তাকিয়েছে।'),
  noteName(
      'No head turn was detected after the name call in {n} measured tries.',
      'মাপা {n}টি চেষ্টায় নাম ধরে ডাকার পর মাথা ঘোরানো শনাক্ত হয়নি।'),
  noteLook(
      '{name} did not look toward the toy {guide} looked at in {n} measured tries.',
      'মাপা {n}টি চেষ্টায় {guide} যে খেলনার দিকে তাকিয়েছিল, {name} সেদিকে তাকায়নি।'),
  noteCopy('No copied movement was detected in {n} measured tries.', 'মাপা {n}টি চেষ্টায় কোনো নকল ভঙ্গি শনাক্ত হয়নি।'),
  sumStory('Looked toward {guide} for {pct}% of the measured time.', 'মাপা সময়ের {pct}% {guide}-এর দিকে তাকিয়েছে।'),
  sumName('Turned toward the call in {n} of {total} measured tries.', 'মাপা {total}টির মধ্যে {n}টি চেষ্টায় ডাকের দিকে মাথা ঘুরিয়েছে।'),
  sumLatency('Typical time: {sec} s.', 'সাধারণ সময়: {sec} সেকেন্ড।'),
  sumLook('Followed {guide}’s look in {n} of {total} measured tries.', 'মাপা {total}টির মধ্যে {n}টি চেষ্টায় {guide}-এর দৃষ্টি অনুসরণ করেছে।'),
  sumBubble('Popped {n} bubbles from {taps} taps.', '{taps}টি ট্যাপে {n}টি বুদবুদ ফাটিয়েছে।'),
  sumCopy('Copied the movement in {n} of {total} measured tries.', 'মাপা {total}টির মধ্যে {n}টি চেষ্টায় ভঙ্গি নকল করেছে।'),
  sumSwitch(
      'Correct taps: {a} of {b} before the switch, {c} of {d} after.',
      'সঠিক ট্যাপ: বদলের আগে {b}টির মধ্যে {a}টি, বদলের পরে {d}টির মধ্যে {c}টি।'),
  copyHeader('Sanket observation session', 'সংকেত পর্যবেক্ষণ সেশন'),
  copyNotDiagnosis('This is not a diagnosis.', 'এটি রোগনির্ণয় নয়।'),

  // ── History ──────────────────────────────────────────────────────────
  historyOverline('Parent dashboard', 'অভিভাবকের ড্যাশবোর্ড'),
  historyTitle('Sessions over time', 'সময়ের সাথে সেশনগুলো'),
  historyLead(
      'Only sessions saved on this phone appear here. Results are observations, not scores.',
      'শুধু এই ফোনে সংরক্ষিত সেশনগুলো এখানে দেখা যায়। ফলাফলগুলো পর্যবেক্ষণ, স্কোর নয়।'),
  historyEmpty('No saved sessions yet.', 'এখনো কোনো সংরক্ষিত সেশন নেই।'),
  historyTrendTitle('Measured activities per session', 'প্রতি সেশনে মাপা কার্যক্রম'),
  historyTrendEmpty('A trend appears after two saved sessions.', 'দুটি সংরক্ষিত সেশনের পর একটি ধারা দেখা যাবে।'),
  historyTrendCaption(
      'Each bar shows how many activities had enough reliable measurement — a data-quality view, not a developmental score.',
      'প্রতিটি বার দেখায় কতগুলো কার্যক্রমে যথেষ্ট নির্ভরযোগ্য মাপ পাওয়া গেছে — এটি তথ্যের মান, বিকাশের স্কোর নয়।'),
  historyMeasured('{n} of {total} activities measured', '{total}টির মধ্যে {n}টি কার্যক্রম মাপা হয়েছে'),
  historyChild('{name} · {age} months', '{name} · {age} মাস'),
  sessionCompleted('Completed', 'সম্পন্ন'),
  sessionStopped('Ended early', 'আগেই শেষ'),
  sessionInterrupted('Interrupted', 'বাধাগ্রস্ত'),
  sessionTimeLimit('Time limit reached', 'সময়সীমা শেষ'),
  sessionInProgress('In progress', 'চলমান'),
  historyDeleteAll('Delete all saved sessions', 'সব সংরক্ষিত সেশন মুছুন'),
  historyDeleteTitle('Delete all sessions?', 'সব সেশন মুছবেন?'),
  historyDeleteBody(
      'This removes every saved session from this phone. It cannot be undone.',
      'এটি এই ফোন থেকে সব সংরক্ষিত সেশন মুছে ফেলবে। আর ফেরানো যাবে না।'),
  historyDelete('Delete', 'মুছুন'),
  historyNewSession('Start another session', 'আরেকটি সেশন শুরু করুন'),
  historyPrivacy(
      'No facial identity recognition, no background recording, and no raw video or audio is ever kept.',
      'মুখ দেখে পরিচয় শনাক্ত করা, পটভূমিতে রেকর্ডিং বা মূল ভিডিও-অডিও রাখা — কোনোটাই হয় না।'),
  ;

  const T(this.en, this.bn);
  final String en;
  final String bn;
}
