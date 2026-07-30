class AppStrings {
  static String intToSwahiliWord(int number) {
    switch (number) {
      case 1: return "moja";
      case 2: return "mbili";
      case 3: return "tatu";
      case 4: return "nne";
      case 5: return "tano";
      case 6: return "sita";
      default: return number.toString();
    }
  }

  static String getNavigationReminder(String langCode) {
    if (langCode.startsWith("sw")) {
      return "Telezesha kidole kimoja chini ili kuendelea. Telezesha kidole kimoja kushoto kurudi nyuma. Gonga mara mbili kurudia maelekezo. Vidole viwili kulia kupata dokezo. Na vidole vitatu chini kubadili lugha. Wakati wowote, shikilia skrini kwa kidole kimoja kwa sekunde sita kufungua ukurasa wa mwalimu.";
    }
    return "Swipe down with one finger to continue. Swipe left with one finger to go back. Double tap to repeat instructions. Swipe right with two fingers for a hint. Swipe down with three fingers to switch between English and Swahili. At any time, press and hold anywhere on the screen with one finger for six seconds to open the Teacher Portal.";
  }

  static String getContinuing(String langCode) => langCode.startsWith("sw") ? "Inaendelea..." : "Continuing...";
  static String getGoingBack(String langCode) => langCode.startsWith("sw") ? "Inarudi nyuma..." : "Going back...";
  static String getRepeating(String langCode) => langCode.startsWith("sw") ? "Inarudia..." : "Repeating...";

  static String getEndOfLessons(String langCode) {
    return langCode.startsWith("sw")
        ? "Hongera sana! Umemaliza masomo yote. Wewe ni nyota wa nukta nundu. Telezesha vidole viwili chini kurudi nyumbani."
        : "Congratulations! You have completed all the lessons. You are a Braille superstar. Swipe down with two fingers to return to the home menu.";
  }

  static String getWrongSingleDot(String langCode, int dot) {
    return langCode.startsWith("sw")
        ? "Hapana, hicho ni kitone cha ${intToSwahiliWord(dot)}. Jaribu tena."
        : "Oops, that is dot $dot. Try again.";
  }

  static String getWrongMultipleDots(String langCode) {
    return langCode.startsWith("sw")
        ? "Sio sahihi bado. Jaribu tena."
        : "Not quite. Try again.";
  }

  static String getCorrectNextLetter(String langCode, String nextLetter) {
    return langCode.startsWith("sw")
        ? "Sahihi. Sasa andika $nextLetter."
        : "Great. Now type $nextLetter.";
  }

  static String getGatewayWelcome(String langCode) => langCode.startsWith("sw") ? "Karibu Nuru Touch. Telezesha kidole kimoja kushoto kwa Kiswahili." : "Welcome to Nuru Touch. Swipe right with one finger for English.";
  
  static String getGatewaySelected(String langCode) => langCode.startsWith("sw") ? "Kiswahili kimechaguliwa. Nuru Touch inaanza." : "English selected. Starting Nuru Touch.";

  static String getOrientationGoodPosture(String langCode) => langCode.startsWith("sw") ? "Mkao mzuri." : "Perfect position.";

  static String getOrientationHoldFlat(String langCode) => langCode.startsWith("sw") ? "Tujitayarishe! Tafadhali shikilia simu yako kwa mapana. Iweke bapa kifuani mwako, na uishikilie kwa vidole vyako vya mwisho na gumba ili isitikisike." : "Let's get ready! Please turn your phone sideways. Hold it flat near your chest, gripping the edges with your pinkies and thumbs to keep it steady.";

  static String getOrientationUpright(String langCode) => langCode.startsWith("sw") ? "Simu imesimama. Tafadhali ishike kwa mapana." : "Phone is upright. Please turn it sideways.";

  static String getCalibrationInstructions(String langCode) => langCode.startsWith("sw") ? "Hebu tuifundishe simu mahali vidole vyako vilipo. Weka vidole vyako vitatu vya katikati kwa kila mkono kwenye skrini kwa pamoja, na usiviondoe." : "Let's teach the phone where your fingers are. Rest your three middle fingers on each hand on the screen at the same time, and hold them still.";

  static String getHomeWelcome(String langCode) => langCode.startsWith("sw") ? "Karibu Nyumbani. Gusa kitone cha kwanza kufungua Masomo." : "Welcome to Home. Tap dot 1 to open Lessons. Tap dot 2 to open Practice.";

  static String getHomeLessonsSelected(String langCode) => langCode.startsWith("sw") ? "Masomo yamechaguliwa." : "Lessons selected.";

  static String getHomePracticeLocked(String langCode) => langCode.startsWith("sw") ? "Mazoezi yamefungwa." : "Practice mode is locked.";

  static String getGridIntro(String langCode) {
    return langCode.startsWith("sw") 
        ? "Tujifunze gridi ya nukta nundu. Gridi ina vitone sita, katika safu mbili wima na mistari mitatu mlalo. Tutajifunza kugusa kila kitone. Telezesha kidole kimoja chini kuanza."
        : "Let's learn the braille grid. The grid has six dots, arranged in two columns and three rows. We will practice finding each dot. Swipe down with one finger to begin.";
  }

  static String getGridTrainingStep(String langCode, int step) {
    if (langCode.startsWith("sw")) {
      switch(step) {
        case 1: return "Kitone cha kwanza kiko juu upande wa kushoto. Kiguse kwa kidole chako cha pete cha kushoto sasa.";
        case 2: return "Kitone cha pili kiko katikati upande wa kushoto. Kiguse kwa kidole chako cha kati cha kushoto sasa.";
        case 3: return "Kitone cha tatu kiko chini upande wa kushoto. Kiguse kwa kidole chako cha shahada cha kushoto sasa.";
        case 4: return "Kitone cha nne kiko juu upande wa kulia. Kiguse kwa kidole chako cha pete cha kulia sasa.";
        case 5: return "Kitone cha tano kiko katikati upande wa kulia. Kiguse kwa kidole chako cha kati cha kulia sasa.";
        case 6: return "Kitone cha sita kiko chini upande wa kulia. Kiguse kwa kidole chako cha shahada cha kulia sasa.";
        default: return "";
      }
    } else {
      switch(step) {
        case 1: return "The top left dot is dot 1. Tap it with your left ring finger now.";
        case 2: return "The middle left dot is dot 2. Tap it with your left middle finger now.";
        case 3: return "The bottom left dot is dot 3. Tap it with your left index finger now.";
        case 4: return "The top right dot is dot 4. Tap it with your right ring finger now.";
        case 5: return "The middle right dot is dot 5. Tap it with your right middle finger now.";
        case 6: return "The bottom right dot is dot 6. Tap it with your right index finger now.";
        default: return "";
      }
    }
  }

  static String getGridTrainingComplete(String langCode) => langCode.startsWith("sw") ? "Vizuri sana! Mafunzo yamekamilika. Telezesha kidole kimoja chini kwenda Nyumbani." : "Brilliant! Training is complete. Swipe down with one finger to go to the Home Menu.";

  static String getRawTouchWarning(String langCode) => langCode.startsWith("sw") ? "Tafadhali andika kwanza." : "Please type the answer first.";
}
