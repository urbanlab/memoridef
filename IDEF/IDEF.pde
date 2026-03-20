import processing.core.PApplet; //<>//
import processing.core.PImage;

import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.*;

// ====================================================
// RÉGLAGES
// ====================================================
int controlDisplay = 1;
int outputDisplay  = 2;
int serverPort = 8080;

// ====================================================
// COULEURS
// ====================================================
color C_BG       = color(255, 255, 255);
color C_PANEL    = color(252, 252, 252);
color C_LINE     = color(225, 232, 238);
color C_TEXT     = color(35, 45, 55);
color C_MUTED    = color(110, 125, 140);

color C_BLUE     = color(145, 220, 255);
color C_BLUE_2   = color(228, 246, 255);

color C_ORANGE   = color(255, 179, 107);
color C_ORANGE_2 = color(255, 239, 221);

// ====================================================
// ÉCRANS
// ====================================================
final int SCREEN_MENU = 0;
final int SCREEN_VIEWER = 1;
final int SCREEN_SCAN_PHOTO = 2;
final int SCREEN_EDUCATOR = 3;
final int SCREEN_PARTICIPANT_COUNT = 4;
final int SCREEN_PARTICIPANTS = 5;
final int SCREEN_ARCHIVE = 6;

int currentScreen = SCREEN_MENU;

// ====================================================
// DONNÉES GLOBALES
// ====================================================
SharedState shared;
UploadServer uploadServer;
DisplayWindow displayWindow;

String uploadsDir;
String encodedDir;
String metadataCsvPath;
String sessionTempPath;
String idCounterPath;
String localIp = "localhost";

HashMap<String, PImage> controlCache = new HashMap<String, PImage>();
HashMap<Integer, PImage> placePngCache = new HashMap<Integer, PImage>();

int minYear = 1960;
int maxYear;

// ====================================================
// SESSION IDENTITÉ
// ====================================================
String educatorName = "";
String[] participantNames = { "", "", "", "" };
int participantCount = 0;
int activeParticipant = -1;
boolean sessionIdentityReady = false;

// ====================================================
// CARTE / LIEUX
// ====================================================
PImage placeMapImage;
ArrayList<PlaceZone> placeZones = new ArrayList<PlaceZone>();
boolean placeMapDebug = false;

// ====================================================
// VISIONNEUSE ARCHIVES
// ====================================================
ArrayList<ImageRecord> viewerRecords = new ArrayList<ImageRecord>();
int viewerCurrentIndex = -1;
int viewerDay = 1;
int viewerMonth = 1;
int viewerYear = 2024;

// ====================================================
// UI MENU
// ====================================================
float menuBtnX, menuBtnY1, menuBtnY2, menuBtnY3, menuBtnW, menuBtnH;

// ====================================================
// UI EDUCATEUR
// ====================================================
float educatorDoneX, educatorDoneY, educatorDoneW, educatorDoneH;

// ====================================================
// UI NB PARTICIPANTS
// ====================================================
float participantCountBtnX, participantCountBtnW, participantCountBtnH;
float participantCountBtnY1, participantCountBtnY2, participantCountBtnY3, participantCountBtnY4;
float participantCountContinueX, participantCountContinueY, participantCountContinueW, participantCountContinueH;

// ====================================================
// UI COMMUNE VIEWER / ARCHIVE
// ====================================================
float previewAreaX, previewAreaY, previewAreaW, previewAreaH;
float metaPanelX, metaPanelY, metaPanelW, metaPanelH;

float daySliderX, daySliderY;
float monthSliderX, monthSliderY;
float yearSliderX, yearSliderY;
float sliderW, sliderH = 16;
String activeSlider = "";

float leftBtnX, rightBtnX, btnY, btnW, btnH;

// ====================================================
// UI ARCHIVAGE
// ====================================================
float placeMapX, placeMapY, placeMapW, placeMapH;
float placeInfoX, placeInfoY, placeInfoW, placeInfoH;

float validateBtnX, validateBtnY, validateBtnW, validateBtnH;
float endSessionBtnX, endSessionBtnY, endSessionBtnW, endSessionBtnH;

boolean archiveFlipped = false;
float flipBtnX, flipBtnY, flipBtnW, flipBtnH;

// ====================================================
// MESSAGES
// ====================================================
String flashMessage = "";
int flashMessageUntil = 0;

// ====================================================
// CLAVIER
// ====================================================
String[][] keyboardRows = {
  { "A", "B", "C", "D", "E", "F", "G" },
  { "H", "I", "J", "K", "L", "M", "N" },
  { "O", "P", "Q", "R", "S", "T", "U" },
  { "V", "W", "X", "Y", "Z", " ", "<" }
};

// ====================================================
// SETUP / DRAW
// ====================================================
void settings() {
  fullScreen(controlDisplay);
}

void setup() {
  surface.setTitle("Contrôle tactile");
  textFont(createFont("Arial", 22));
  noStroke();

  Calendar cal = Calendar.getInstance();
  maxYear = cal.get(Calendar.YEAR) + 10;

  uploadsDir = sketchPath("uploads");
  encodedDir = sketchPath("encoded");
  metadataCsvPath = sketchPath("metadata.csv");
  sessionTempPath = sketchPath("session_temp.csv");
  idCounterPath = sketchPath("last_image_id.txt");

  File uploadsFolder = new File(uploadsDir);
  if (!uploadsFolder.exists()) uploadsFolder.mkdirs();

  File encodedFolder = new File(encodedDir);
  if (!encodedFolder.exists()) encodedFolder.mkdirs();

  localIp = findLocalIPv4();
  shared = new SharedState();

  placeMapImage = loadImage("carte_lieux.png");
  initPlaceZones();

  recoverSessionTempIfPresent();
  loadViewerRecords();

  uploadServer = new UploadServer(serverPort, uploadsDir, shared);
  uploadServer.start();

  displayWindow = new DisplayWindow(outputDisplay);
  PApplet.runSketch(new String[] { "DisplayWindow" }, displayWindow);

  println("========================================");
  println("Serveur lancé");
  println("Local        : http://localhost:" + serverPort);
  println("Téléphone    : http://" + localIp + ":" + serverPort);
  println("Carte        : " + sketchPath("data/carte_lieux.png"));
  println("Places dir   : " + sketchPath("data/places"));
  println("========================================");
}

void draw() {
  background(C_BG);

  switch(currentScreen) {
  case SCREEN_MENU:
    drawStartMenu();
    break;

  case SCREEN_VIEWER:
    drawViewerScreen();
    break;

  case SCREEN_SCAN_PHOTO:
    drawStubScreen("Archivage via scan photo", "Pas encore codé.");
    break;

  case SCREEN_EDUCATOR:
    drawEducatorScreen();
    break;

  case SCREEN_PARTICIPANT_COUNT:
    drawParticipantCountScreen();
    break;

  case SCREEN_PARTICIPANTS:
    drawParticipantsScreen();
    break;

  case SCREEN_ARCHIVE:
    drawArchiveMode();
    break;
  }
}

// ====================================================
// INPUT ROUTER
// ====================================================
void mousePressed() {
  switch(currentScreen) {
  case SCREEN_MENU:
    mousePressedStartMenu();
    break;

  case SCREEN_VIEWER:
    mousePressedViewerScreen();
    break;

  case SCREEN_SCAN_PHOTO:
    if (isOverBackToMenuButton()) currentScreen = SCREEN_MENU;
    break;

  case SCREEN_EDUCATOR:
    mousePressedEducatorScreen();
    break;

  case SCREEN_PARTICIPANT_COUNT:
    mousePressedParticipantCountScreen();
    break;

  case SCREEN_PARTICIPANTS:
    mousePressedParticipantsScreen();
    break;

  case SCREEN_ARCHIVE:
    mousePressedArchiveMode();
    break;
  }
}

void mouseDragged() {
  if (currentScreen == SCREEN_ARCHIVE) mouseDraggedArchiveMode();
  if (currentScreen == SCREEN_VIEWER) mouseDraggedViewerScreen();
}

void mouseReleased() {
  if (currentScreen == SCREEN_ARCHIVE) mouseReleasedArchiveMode();
  if (currentScreen == SCREEN_VIEWER) mouseReleasedViewerScreen();
}

void keyPressed() {
  if (currentScreen == SCREEN_ARCHIVE) keyPressedArchiveMode();
  if (currentScreen == SCREEN_VIEWER) keyPressedViewerScreen();
}

// ====================================================
// MENU
// ====================================================
void layoutStartMenu(float rw, float rh) {
  menuBtnW = min(720, rw * 0.56);
  menuBtnH = 110;
  menuBtnX = (rw - menuBtnW) / 2.0;

  float gap = 28;
  float totalH = menuBtnH * 3 + gap * 2;
  float startY = (rh - totalH) / 2.0;

  menuBtnY1 = startY;
  menuBtnY2 = startY + menuBtnH + gap;
  menuBtnY3 = startY + (menuBtnH + gap) * 2;
}

void drawStartMenu() {
  background(C_BG);

  pushMatrix();
  translate(width, 0);
  rotate(HALF_PI);

  float rw = height;
  float rh = width;
  layoutStartMenu(rw, rh);

  fill(C_TEXT);
  textAlign(CENTER, TOP);
  textSize(38);
  text("Choix du mode", rw / 2.0, 70);

  drawMenuButton(menuBtnX, menuBtnY1, menuBtnW, menuBtnH,
    "Visionneuse archives",
    isOverRectLocal(portraitMouseX(), portraitMouseY(), menuBtnX, menuBtnY1, menuBtnW, menuBtnH));

  drawMenuButton(menuBtnX, menuBtnY2, menuBtnW, menuBtnH,
    "Archiver via scan photo",
    isOverRectLocal(portraitMouseX(), portraitMouseY(), menuBtnX, menuBtnY2, menuBtnW, menuBtnH));

  drawMenuButton(menuBtnX, menuBtnY3, menuBtnW, menuBtnH,
    "Mode archivage",
    isOverRectLocal(portraitMouseX(), portraitMouseY(), menuBtnX, menuBtnY3, menuBtnW, menuBtnH));

  fill(C_MUTED);
  textSize(16);
  text("La visionneuse parcourt metadata.csv avec jour / mois / année.", rw / 2.0, menuBtnY3 + menuBtnH + 30);

  if (shared.getCount() > 0 && sessionIdentityReady) {
    fill(C_BLUE);
    text("Une session temporaire a été récupérée.", rw / 2.0, menuBtnY3 + menuBtnH + 58);
  }

  popMatrix();
}

void drawMenuButton(float x, float y, float w, float h, String label, boolean over) {
  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.5);
  fill(over ? C_BLUE_2 : color(255));
  rect(x, y, w, h, 20);
  popStyle();

  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(28);
  text(label, x + w / 2.0, y + h / 2.0);
}

void mousePressedStartMenu() {
  float rx = portraitMouseX();
  float ry = portraitMouseY();

  if (isOverRectLocal(rx, ry, menuBtnX, menuBtnY1, menuBtnW, menuBtnH)) {
    loadViewerRecords();
    currentScreen = SCREEN_VIEWER;
    return;
  }

  if (isOverRectLocal(rx, ry, menuBtnX, menuBtnY2, menuBtnW, menuBtnH)) {
    currentScreen = SCREEN_SCAN_PHOTO;
    return;
  }

  if (isOverRectLocal(rx, ry, menuBtnX, menuBtnY3, menuBtnW, menuBtnH)) {
    if (shared.getCount() > 0 && sessionIdentityReady) {
      currentScreen = SCREEN_ARCHIVE;
    } else {
      educatorName = "";
      participantNames = new String[] { "", "", "", "" };
      participantCount = 0;
      activeParticipant = -1;
      sessionIdentityReady = false;
      currentScreen = SCREEN_EDUCATOR;
    }
    return;
  }
}

// ====================================================
// STUB
// ====================================================
void drawStubScreen(String title, String subtitle) {
  background(C_BG);

  pushMatrix();
  translate(width, 0);
  rotate(HALF_PI);

  float rw = height;
  float rh = width;

  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(34);
  text(title, rw / 2.0, rh / 2.0 - 60);

  fill(C_MUTED);
  textSize(20);
  text(subtitle, rw / 2.0, rh / 2.0);

  drawBackToMenuButtonLocal(isOverRectLocal(portraitMouseX(), portraitMouseY(), 40, 40, 260, 70));

  popMatrix();
}

void drawBackToMenuButtonLocal(boolean over) {
  float w = 260;
  float h = 70;
  float x = 40;
  float y = 40;

  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.5);
  fill(over ? C_BLUE_2 : color(255));
  rect(x, y, w, h, 16);
  popStyle();

  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(24);
  text("Retour menu", x + w / 2.0, y + h / 2.0);
}

boolean isOverBackToMenuButton() {
  return isOverRectLocal(portraitMouseX(), portraitMouseY(), 40, 40, 260, 70);
}

// ====================================================
// CLAVIER
// ====================================================
void drawKeyboardLocal(float x, float y, float w, float h, boolean highlight) {
  float gap = 10;
  int rows = keyboardRows.length;
  float keyH = (h - gap * (rows - 1)) / rows;

  for (int r = 0; r < rows; r++) {
    int cols = keyboardRows[r].length;
    float keyW = (w - gap * (cols - 1)) / cols;

    for (int c = 0; c < cols; c++) {
      float kx = x + c * (keyW + gap);
      float ky = y + r * (keyH + gap);

      pushStyle();
      stroke(C_LINE);
      strokeWeight(1.2);
      fill(highlight ? C_BLUE_2 : color(255));
      rect(kx, ky, keyW, keyH, 12);
      popStyle();

      fill(C_TEXT);
      textAlign(CENTER, CENTER);
      textSize(min(28, keyH * 0.38));
      String label = keyboardRows[r][c];
      if (label.equals(" ")) label = "ESPACE";
      if (label.equals("<")) label = "EFF";
      text(label, kx + keyW / 2.0, ky + keyH / 2.0);
    }
  }
}

String keyHitLocal(float mx, float my, float x, float y, float w, float h) {
  float gap = 10;
  int rows = keyboardRows.length;
  float keyH = (h - gap * (rows - 1)) / rows;

  for (int r = 0; r < rows; r++) {
    int cols = keyboardRows[r].length;
    float keyW = (w - gap * (cols - 1)) / cols;

    for (int c = 0; c < cols; c++) {
      float kx = x + c * (keyW + gap);
      float ky = y + r * (keyH + gap);

      if (mx >= kx && mx <= kx + keyW && my >= ky && my <= ky + keyH) {
        return keyboardRows[r][c];
      }
    }
  }
  return "";
}

String sanitizeSimpleName(String s) {
  s = s.toUpperCase();
  String out = "";

  for (int i = 0; i < s.length(); i++) {
    char ch = s.charAt(i);
    if ((ch >= 'A' && ch <= 'Z') || ch == ' ' ||
      ch == 'É' || ch == 'È' || ch == 'Ê' || ch == 'Ë' ||
      ch == 'À' || ch == 'Â' || ch == 'Ä' ||
      ch == 'Î' || ch == 'Ï' ||
      ch == 'Ô' || ch == 'Ö' ||
      ch == 'Ù' || ch == 'Û' || ch == 'Ü' ||
      ch == 'Ç') {
      out += ch;
    }
  }

  while (out.indexOf("  ") != -1) {
    out = out.replace("  ", " ");
  }
  return trim(out);
}

// ====================================================
// ÉDUCATEUR
// ====================================================
void drawEducatorScreen() {
  background(C_BG);

  pushMatrix();
  translate(width, 0);
  rotate(HALF_PI);

  float rw = height;
  float rh = width;

  fill(C_TEXT);
  textAlign(CENTER, TOP);
  textSize(34);
  text("Nom de l’éducateur", rw / 2.0, 40);

  float boxX = rw * 0.12;
  float boxY = 120;
  float boxW = rw * 0.76;
  float boxH = 90;

  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.5);
  fill(255);
  rect(boxX, boxY, boxW, boxH, 18);
  popStyle();

  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(30);
  String shown = educatorName.length() == 0 ? "TAPER LE NOM" : educatorName;
  text(shown, boxX + boxW / 2.0, boxY + boxH / 2.0);

  float kbX = rw * 0.08;
  float kbY = 250;
  float kbW = rw * 0.84;
  float kbH = rh - kbY - 170;

  drawKeyboardLocal(kbX, kbY, kbW, kbH, true);

  educatorDoneW = 320;
  educatorDoneH = 70;
  educatorDoneX = (rw - educatorDoneW) / 2.0;
  educatorDoneY = rh - 100;

  boolean over = isOverRectLocal(portraitMouseX(), portraitMouseY(), educatorDoneX, educatorDoneY, educatorDoneW, educatorDoneH);

  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.5);
  fill(educatorName.length() > 0 ? (over ? C_ORANGE : C_ORANGE_2) : color(242));
  rect(educatorDoneX, educatorDoneY, educatorDoneW, educatorDoneH, 16);
  popStyle();

  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(24);
  text("Valider", educatorDoneX + educatorDoneW / 2.0, educatorDoneY + educatorDoneH / 2.0);

  popMatrix();
}

void mousePressedEducatorScreen() {
  float rx = portraitMouseX();
  float ry = portraitMouseY();
  float rw = height;
  float rh = width;

  float kbX = rw * 0.08;
  float kbY = 250;
  float kbW = rw * 0.84;
  float kbH = rh - kbY - 170;

  if (rx >= educatorDoneX && rx <= educatorDoneX + educatorDoneW &&
    ry >= educatorDoneY && ry <= educatorDoneY + educatorDoneH) {
    if (educatorName.length() > 0) {
      participantCount = 0;
      activeParticipant = -1;
      currentScreen = SCREEN_PARTICIPANT_COUNT;
    }
    return;
  }

  String key = keyHitLocal(rx, ry, kbX, kbY, kbW, kbH);
  if (!key.equals("")) {
    if (key.equals("<")) {
      if (educatorName.length() > 0) educatorName = educatorName.substring(0, educatorName.length() - 1);
    } else {
      educatorName = sanitizeSimpleName(educatorName + key);
    }
  }
}

// ====================================================
// CHOIX NOMBRE PARTICIPANTS
// ====================================================
void layoutParticipantCountScreen(float rw, float rh) {
  participantCountBtnW = min(520, rw * 0.58);
  participantCountBtnH = 86;
  participantCountBtnX = (rw - participantCountBtnW) / 2.0;

  float gap = 18;
  float totalH = participantCountBtnH * 4 + gap * 3;
  float startY = (rh - totalH) / 2.0 - 40;

  participantCountBtnY1 = startY;
  participantCountBtnY2 = participantCountBtnY1 + participantCountBtnH + gap;
  participantCountBtnY3 = participantCountBtnY2 + participantCountBtnH + gap;
  participantCountBtnY4 = participantCountBtnY3 + participantCountBtnH + gap;

  participantCountContinueW = 320;
  participantCountContinueH = 72;
  participantCountContinueX = (rw - participantCountContinueW) / 2.0;
  participantCountContinueY = participantCountBtnY4 + participantCountBtnH + 40;
}

void drawParticipantCountScreen() {
  background(C_BG);

  pushMatrix();
  translate(width, 0);
  rotate(HALF_PI);

  float rw = height;
  float rh = width;
  layoutParticipantCountScreen(rw, rh);

  fill(C_TEXT);
  textAlign(CENTER, TOP);
  textSize(34);
  text("Nombre de participants", rw / 2.0, 50);

  fill(C_MUTED);
  textSize(20);
  text("Choisis combien de participants seront saisis", rw / 2.0, 100);

  drawParticipantCountChoiceButton(1, participantCountBtnX, participantCountBtnY1, participantCountBtnW, participantCountBtnH,
    isOverRectLocal(portraitMouseX(), portraitMouseY(), participantCountBtnX, participantCountBtnY1, participantCountBtnW, participantCountBtnH));

  drawParticipantCountChoiceButton(2, participantCountBtnX, participantCountBtnY2, participantCountBtnW, participantCountBtnH,
    isOverRectLocal(portraitMouseX(), portraitMouseY(), participantCountBtnX, participantCountBtnY2, participantCountBtnW, participantCountBtnH));

  drawParticipantCountChoiceButton(3, participantCountBtnX, participantCountBtnY3, participantCountBtnW, participantCountBtnH,
    isOverRectLocal(portraitMouseX(), portraitMouseY(), participantCountBtnX, participantCountBtnY3, participantCountBtnW, participantCountBtnH));

  drawParticipantCountChoiceButton(4, participantCountBtnX, participantCountBtnY4, participantCountBtnW, participantCountBtnH,
    isOverRectLocal(portraitMouseX(), portraitMouseY(), participantCountBtnX, participantCountBtnY4, participantCountBtnW, participantCountBtnH));

  boolean overContinue = isOverRectLocal(portraitMouseX(), portraitMouseY(), participantCountContinueX, participantCountContinueY, participantCountContinueW, participantCountContinueH);

  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.5);
  fill(participantCount > 0 ? (overContinue ? C_ORANGE : C_ORANGE_2) : color(242));
  rect(participantCountContinueX, participantCountContinueY, participantCountContinueW, participantCountContinueH, 16);
  popStyle();

  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(24);
  text("Continuer", participantCountContinueX + participantCountContinueW / 2.0, participantCountContinueY + participantCountContinueH / 2.0);

  popMatrix();
}

void drawParticipantCountChoiceButton(int count, float x, float y, float w, float h, boolean over) {
  boolean selected = (participantCount == count);

  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.5);
  if (selected) fill(over ? C_BLUE : C_BLUE_2);
  else fill(over ? color(248) : color(255));
  rect(x, y, w, h, 16);
  popStyle();

  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(28);
  text(str(count) + " participant" + (count > 1 ? "s" : ""), x + w / 2.0, y + h / 2.0);
}

void mousePressedParticipantCountScreen() {
  float rx = portraitMouseX();
  float ry = portraitMouseY();

  if (isOverRectLocal(rx, ry, participantCountBtnX, participantCountBtnY1, participantCountBtnW, participantCountBtnH)) {
    participantCount = 1;
    return;
  }
  if (isOverRectLocal(rx, ry, participantCountBtnX, participantCountBtnY2, participantCountBtnW, participantCountBtnH)) {
    participantCount = 2;
    return;
  }
  if (isOverRectLocal(rx, ry, participantCountBtnX, participantCountBtnY3, participantCountBtnW, participantCountBtnH)) {
    participantCount = 3;
    return;
  }
  if (isOverRectLocal(rx, ry, participantCountBtnX, participantCountBtnY4, participantCountBtnW, participantCountBtnH)) {
    participantCount = 4;
    return;
  }

  if (isOverRectLocal(rx, ry, participantCountContinueX, participantCountContinueY, participantCountContinueW, participantCountContinueH)) {
    if (participantCount > 0) {
      for (int i = participantCount; i < 4; i++) participantNames[i] = "";
      activeParticipant = 0;
      currentScreen = SCREEN_PARTICIPANTS;
    }
  }
}

// ====================================================
// PARTICIPANTS
// ====================================================
void drawParticipantsScreen() {
  background(C_BG);

  drawParticipantQuadrant(0, 0, 0, width / 2.0, height / 2.0, true);
  drawParticipantQuadrant(1, width / 2.0, 0, width / 2.0, height / 2.0, true);
  drawParticipantQuadrant(2, 0, height / 2.0, width / 2.0, height / 2.0, false);
  drawParticipantQuadrant(3, width / 2.0, height / 2.0, width / 2.0, height / 2.0, false);

  drawParticipantsContinueButton();
}

void drawParticipantQuadrant(int idx, float x, float y, float w, float h, boolean rotated180) {
  pushMatrix();
  if (rotated180) {
    translate(x + w, y + h);
    rotate(PI);
    drawParticipantQuadrantLocal(idx, w, h);
  } else {
    translate(x, y);
    drawParticipantQuadrantLocal(idx, w, h);
  }
  popMatrix();
}

void drawParticipantQuadrantLocal(int idx, float w, float h) {
  boolean enabled = idx < participantCount;

  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.5);
  fill(enabled ? color(255) : color(245));
  rect(8, 8, w - 16, h - 16, 18);
  popStyle();

  fill(enabled ? C_TEXT : C_MUTED);
  textAlign(CENTER, TOP);
  textSize(24);
  text("Participant " + (idx + 1), w / 2.0, 20);

  float nameX = 24;
  float nameY = 64;
  float nameW = w - 48;
  float nameH = 64;

  boolean selected = enabled && (activeParticipant == idx);

  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.3);
  if (enabled) fill(selected ? C_BLUE_2 : color(255));
  else fill(color(242));
  rect(nameX, nameY, nameW, nameH, 14);
  popStyle();

  fill(enabled ? C_TEXT : C_MUTED);
  textAlign(CENTER, CENTER);
  textSize(22);

  String shown;
  if (!enabled) shown = "NON UTILISÉ";
  else shown = participantNames[idx].length() == 0 ? "TAPER LE NOM" : participantNames[idx];

  text(shown, nameX + nameW / 2.0, nameY + nameH / 2.0);

  float kbX = 24;
  float kbY = 148;
  float kbW = w - 48;
  float kbH = h - kbY - 24;

  if (enabled) {
    drawKeyboardLocal(kbX, kbY, kbW, kbH, selected);
  } else {
    pushStyle();
    stroke(C_LINE);
    strokeWeight(1.3);
    fill(color(242));
    rect(kbX, kbY, kbW, kbH, 14);
    popStyle();

    fill(C_MUTED);
    textAlign(CENTER, CENTER);
    textSize(22);
    text("Zone inactive", kbX + kbW / 2.0, kbY + kbH / 2.0);
  }
}

void drawParticipantsContinueButton() {
  float w = 260;
  float h = 100;
  float x = width / 2.0 - w / 2.0;
  float y = height / 2.0 - h / 2.0;

  boolean allReady = allParticipantsReady();

  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.5);
  fill(allReady ? C_ORANGE_2 : color(242));
  rect(x, y, w, h, 22);
  popStyle();

  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(24);
  text("Commencer", x + w / 2.0, y + h / 2.0 - 12);
  textSize(18);
  

  pushMatrix();
  translate(width, height);
  rotate(PI);
  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(24);
  text("Commencer", width - (x + w / 2.0), height - (y + h / 2.0) - 12);
  textSize(18);
  popMatrix();
}

boolean isOverParticipantsContinueButton() {
  float w = 260;
  float h = 100;
  float x = width / 2.0 - w / 2.0;
  float y = height / 2.0 - h / 2.0;
  return isOverRect(x, y, w, h);
}

boolean allParticipantsReady() {
  if (participantCount < 1) return false;
  for (int i = 0; i < participantCount; i++) {
    if (trim(participantNames[i]).length() == 0) return false;
  }
  return true;
}

void mousePressedParticipantsScreen() {
  if (isOverParticipantsContinueButton()) {
    if (allParticipantsReady() && educatorName.length() > 0) {
      sessionIdentityReady = true;
      currentScreen = SCREEN_ARCHIVE;
      flash("Session prête : " + educatorName);
    }
    return;
  }

  if (mouseX < width / 2.0 && mouseY < height / 2.0) {
    handleParticipantQuadrantClick(0, width / 2.0 - mouseX, height / 2.0 - mouseY, width / 2.0, height / 2.0);
    return;
  }

  if (mouseX >= width / 2.0 && mouseY < height / 2.0) {
    handleParticipantQuadrantClick(1, width - mouseX, height / 2.0 - mouseY, width / 2.0, height / 2.0);
    return;
  }

  if (mouseX < width / 2.0 && mouseY >= height / 2.0) {
    handleParticipantQuadrantClick(2, mouseX, mouseY - height / 2.0, width / 2.0, height / 2.0);
    return;
  }

  if (mouseX >= width / 2.0 && mouseY >= height / 2.0) {
    handleParticipantQuadrantClick(3, mouseX - width / 2.0, mouseY - height / 2.0, width / 2.0, height / 2.0);
    return;
  }
}

void handleParticipantQuadrantClick(int idx, float lx, float ly, float w, float h) {
  if (idx >= participantCount) return;

  float nameX = 24;
  float nameY = 64;
  float nameW = w - 48;
  float nameH = 64;

  if (lx >= nameX && lx <= nameX + nameW &&
    ly >= nameY && ly <= nameY + nameH) {
    activeParticipant = idx;
    return;
  }

  if (activeParticipant != idx) activeParticipant = idx;

  float kbX = 24;
  float kbY = 148;
  float kbW = w - 48;
  float kbH = h - kbY - 24;

  String key = keyHitLocal(lx, ly, kbX, kbY, kbW, kbH);
  if (!key.equals("")) {
    if (key.equals("<")) {
      if (participantNames[idx].length() > 0) {
        participantNames[idx] = participantNames[idx].substring(0, participantNames[idx].length() - 1);
      }
    } else {
      participantNames[idx] = sanitizeSimpleName(participantNames[idx] + key);
    }
  }
}

int inferParticipantCountFromNames(String[] names) {
  int count = 0;
  for (int i = 0; i < 4; i++) {
    if (trim(names[i]).length() > 0) count++;
  }
  return max(1, count);
}

// ====================================================
// VISIONNEUSE
// ====================================================
void loadViewerRecords() {
  viewerRecords.clear();

  ArrayList<String> lines = readLinesSafe(metadataCsvPath);
  for (String line : lines) {
    ImageRecord rec = csvLineToRecord(line);
    if (rec != null && rec.validated) {
      File f = new File(rec.encodedPath);
      if (!f.exists()) f = new File(rec.path);
      if (f.exists()) {
        if (!f.getAbsolutePath().equals(rec.encodedPath) && f.getAbsolutePath().equals(rec.path)) {
          // ok, on garde le raw si encoded absent
        }
        viewerRecords.add(rec);
      }
    }
  }

  if (viewerRecords.size() > 0) {
    ImageRecord last = viewerRecords.get(viewerRecords.size() - 1);
    viewerCurrentIndex = viewerRecords.size() - 1;
    viewerDay = last.day;
    viewerMonth = last.month;
    viewerYear = last.year;
  } else {
    Calendar cal = Calendar.getInstance();
    viewerCurrentIndex = -1;
    viewerDay = cal.get(Calendar.DAY_OF_MONTH);
    viewerMonth = cal.get(Calendar.MONTH) + 1;
    viewerYear = cal.get(Calendar.YEAR);
  }
}

void drawViewerScreen() {
  layoutViewerUI();

  drawViewerBackButton();

  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.5);
  fill(255);
  rect(previewAreaX, previewAreaY, previewAreaW, previewAreaH, 20);
  rect(metaPanelX, metaPanelY, metaPanelW, metaPanelH, 20);
  popStyle();

  if (viewerRecords.size() == 0 || viewerCurrentIndex < 0 || viewerCurrentIndex >= viewerRecords.size()) {
    fill(C_TEXT);
    textAlign(CENTER, CENTER);
    textSize(30);
    text("Aucune image archivée", previewAreaX + previewAreaW / 2.0, previewAreaY + previewAreaH / 2.0 - 20);

    fill(C_MUTED);
    textSize(18);
    text("metadata.csv est vide ou introuvable", previewAreaX + previewAreaW / 2.0, previewAreaY + previewAreaH / 2.0 + 20);

    drawViewerSlidersOnly();
    return;
  }

  ImageRecord rec = viewerRecords.get(viewerCurrentIndex);
  PImage img = getBestImageForRecord(rec);

  if (img != null) {
    drawImageContain(this, img, previewAreaX + 16, previewAreaY + 16, previewAreaW - 32, previewAreaH - 32);
  } else {
    fill(C_MUTED);
    textAlign(CENTER, CENTER);
    textSize(24);
    text("Image introuvable", previewAreaX + previewAreaW / 2.0, previewAreaY + previewAreaH / 2.0);
  }

  fill(C_TEXT);
  textAlign(LEFT, TOP);
  textSize(22);
  text("Recherche date", metaPanelX + 20, metaPanelY + 18);

  drawSlider("Jour", viewerDay, 1, daysInMonth(viewerYear, viewerMonth), daySliderX, daySliderY, sliderW, sliderH, true);
  drawSlider("Mois", viewerMonth, 1, 12, monthSliderX, monthSliderY, sliderW, sliderH, true);
  drawSlider("Année", viewerYear, minYear, maxYear, yearSliderX, yearSliderY, sliderW, sliderH, true);

  fill(C_MUTED);
  textAlign(CENTER, TOP);
  textSize(16);
  text("Image trouvée", metaPanelX + metaPanelW / 2.0, yearSliderY + 54);

  fill(C_TEXT);
  textSize(16);
  text("Lieu : " + getPlaceName(rec.placeId), metaPanelX + metaPanelW / 2.0, yearSliderY + 84);
  text("Date : " + nf(rec.day, 2) + "/" + nf(rec.month, 2) + "/" + rec.year, metaPanelX + metaPanelW / 2.0, yearSliderY + 110);
  text("ID : " + rec.imageId, metaPanelX + metaPanelW / 2.0, yearSliderY + 136);

  drawViewerNavButtons();
}

void layoutViewerUI() {
  float margin = 30;

  metaPanelW = min(390, width * 0.28);
  metaPanelX = width - margin - metaPanelW;
  metaPanelY = 120;
  metaPanelH = height - metaPanelY - 40;

  previewAreaX = 40;
  previewAreaY = 120;
  previewAreaW = metaPanelX - previewAreaX - 30;
  previewAreaH = height - previewAreaY - 40;

  sliderW = metaPanelW - 40;
  daySliderX = metaPanelX + 20;
  daySliderY = metaPanelY + 90;

  monthSliderX = metaPanelX + 20;
  monthSliderY = daySliderY + 70;

  yearSliderX = metaPanelX + 20;
  yearSliderY = monthSliderY + 70;

  btnH = 76;
  btnY = metaPanelY + metaPanelH - btnH - 20;
  btnW = (metaPanelW - 60) / 2.0;
  leftBtnX = metaPanelX + 20;
  rightBtnX = leftBtnX + btnW + 20;
}

void drawViewerSlidersOnly() {
  fill(C_TEXT);
  textAlign(LEFT, TOP);
  textSize(22);
  text("Recherche date", metaPanelX + 20, metaPanelY + 18);

  drawSlider("Jour", viewerDay, 1, daysInMonth(viewerYear, viewerMonth), daySliderX, daySliderY, sliderW, sliderH, true);
  drawSlider("Mois", viewerMonth, 1, 12, monthSliderX, monthSliderY, sliderW, sliderH, true);
  drawSlider("Année", viewerYear, minYear, maxYear, yearSliderX, yearSliderY, sliderW, sliderH, true);
}

void drawViewerBackButton() {
  float x = 30;
  float y = 78;
  float w = 220;
  float h = 34;

  boolean over = mouseX >= x && mouseX <= x + w && mouseY >= y && mouseY <= y + h;

  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.2);
  fill(over ? C_BLUE_2 : color(255));
  rect(x, y, w, h, 12);
  popStyle();

  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(16);
  text("Retour menu", x + w / 2.0, y + h / 2.0);
}

void drawSlider(String label, int value, int minValue, int maxValue,
                float x, float y, float w, float h, boolean editable) {
  fill(editable ? C_TEXT : C_MUTED);
  textAlign(LEFT, BOTTOM);
  textSize(16);
  text(label + " : " + value, x, y - 10);

  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.2);
  fill(editable ? color(255) : color(245));
  rect(x, y, w, h, 10);
  popStyle();

  float t;
  if (maxValue == minValue) t = 0;
  else t = map(value, minValue, maxValue, 0, 1);

  t = constrain(t, 0, 1);
  float knobX = x + t * w;

  noStroke();
  fill(editable ? C_BLUE : color(210));
  rect(x, y, knobX - x, h, 10);

  fill(editable ? C_ORANGE : color(190));
  ellipse(knobX, y + h / 2.0, 22, 22);

  fill(C_MUTED);
  textSize(12);
  textAlign(LEFT, TOP);
  text(str(minValue), x, y + h + 8);
  textAlign(RIGHT, TOP);
  text(str(maxValue), x + w, y + h + 8);
}


void drawViewerNavButtons() {
  boolean overLeft = mouseX >= leftBtnX && mouseX <= leftBtnX + btnW && mouseY >= btnY && mouseY <= btnY + btnH;
  boolean overRight = mouseX >= rightBtnX && mouseX <= rightBtnX + btnW && mouseY >= btnY && mouseY <= btnY + btnH;

  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.4);
  fill(overLeft ? C_BLUE_2 : color(255));
  rect(leftBtnX, btnY, btnW, btnH, 16);

  fill(overRight ? C_BLUE_2 : color(255));
  rect(rightBtnX, btnY, btnW, btnH, 16);
  popStyle();

  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(32);
  text("◀", leftBtnX + btnW / 2.0, btnY + 28);
  text("▶", rightBtnX + btnW / 2.0, btnY + 28);

  fill(C_MUTED);
  textSize(16);
  text("Précédente", leftBtnX + btnW / 2.0, btnY + 56);
  text("Suivante", rightBtnX + btnW / 2.0, btnY + 56);
}

void mousePressedViewerScreen() {
  float backX = 30;
  float backY = 78;
  float backW = 220;
  float backH = 34;

  if (mouseX >= backX && mouseX <= backX + backW && mouseY >= backY && mouseY <= backY + backH) {
    currentScreen = SCREEN_MENU;
    return;
  }

  if (viewerRecords.size() > 1) {
    if (mouseX >= leftBtnX && mouseX <= leftBtnX + btnW && mouseY >= btnY && mouseY <= btnY + btnH) {
      viewerCurrentIndex--;
      if (viewerCurrentIndex < 0) viewerCurrentIndex = viewerRecords.size() - 1;
      syncViewerDateFromIndex();
      return;
    }

    if (mouseX >= rightBtnX && mouseX <= rightBtnX + btnW && mouseY >= btnY && mouseY <= btnY + btnH) {
      viewerCurrentIndex++;
      if (viewerCurrentIndex >= viewerRecords.size()) viewerCurrentIndex = 0;
      syncViewerDateFromIndex();
      return;
    }
  }

  String sliderHit = getClickedViewerSlider(mouseX, mouseY);
  if (!sliderHit.equals("")) {
    activeSlider = sliderHit;
    updateViewerSlider(mouseX);
  }
}

void mouseDraggedViewerScreen() {
  if (!activeSlider.equals("")) updateViewerSlider(mouseX);
}

void mouseReleasedViewerScreen() {
  activeSlider = "";
}

void keyPressedViewerScreen() {
  if (viewerRecords.size() == 0) return;

  if (keyCode == LEFT) {
    viewerCurrentIndex--;
    if (viewerCurrentIndex < 0) viewerCurrentIndex = viewerRecords.size() - 1;
    syncViewerDateFromIndex();
  } else if (keyCode == RIGHT) {
    viewerCurrentIndex++;
    if (viewerCurrentIndex >= viewerRecords.size()) viewerCurrentIndex = 0;
    syncViewerDateFromIndex();
  }
}

String getClickedViewerSlider(float mx, float my) {
  if (mx >= daySliderX && mx <= daySliderX + sliderW && my >= daySliderY - 8 && my <= daySliderY + sliderH + 8) return "day";
  if (mx >= monthSliderX && mx <= monthSliderX + sliderW && my >= monthSliderY - 8 && my <= monthSliderY + sliderH + 8) return "month";
  if (mx >= yearSliderX && mx <= yearSliderX + sliderW && my >= yearSliderY - 8 && my <= yearSliderY + sliderH + 8) return "year";
  return "";
}

void updateViewerSlider(float mx) {
  if (activeSlider.equals("day")) {
    int maxDay = daysInMonth(viewerYear, viewerMonth);
    viewerDay = sliderValueFromMouse(mx, daySliderX, sliderW, 1, maxDay);
  } else if (activeSlider.equals("month")) {
    viewerMonth = sliderValueFromMouse(mx, monthSliderX, sliderW, 1, 12);
    int maxDay = daysInMonth(viewerYear, viewerMonth);
    if (viewerDay > maxDay) viewerDay = maxDay;
  } else if (activeSlider.equals("year")) {
    viewerYear = sliderValueFromMouse(mx, yearSliderX, sliderW, minYear, maxYear);
    int maxDay = daysInMonth(viewerYear, viewerMonth);
    if (viewerDay > maxDay) viewerDay = maxDay;
  }

  viewerCurrentIndex = findBestViewerIndexForDate(viewerDay, viewerMonth, viewerYear);
}

void syncViewerDateFromIndex() {
  if (viewerCurrentIndex < 0 || viewerCurrentIndex >= viewerRecords.size()) return;
  ImageRecord rec = viewerRecords.get(viewerCurrentIndex);
  viewerDay = rec.day;
  viewerMonth = rec.month;
  viewerYear = rec.year;
}

int findBestViewerIndexForDate(int targetDay, int targetMonth, int targetYear) {
  if (viewerRecords.size() == 0) return -1;

  Calendar target = Calendar.getInstance();
  target.set(Calendar.YEAR, targetYear);
  target.set(Calendar.MONTH, targetMonth - 1);
  target.set(Calendar.DAY_OF_MONTH, targetDay);
  target.set(Calendar.HOUR_OF_DAY, 0);
  target.set(Calendar.MINUTE, 0);
  target.set(Calendar.SECOND, 0);
  target.set(Calendar.MILLISECOND, 0);

  long bestDiff = Long.MAX_VALUE;
  int bestIndex = -1;

  for (int i = 0; i < viewerRecords.size(); i++) {
    ImageRecord r = viewerRecords.get(i);

    Calendar c = Calendar.getInstance();
    c.set(Calendar.YEAR, r.year);
    c.set(Calendar.MONTH, r.month - 1);
    c.set(Calendar.DAY_OF_MONTH, r.day);
    c.set(Calendar.HOUR_OF_DAY, 0);
    c.set(Calendar.MINUTE, 0);
    c.set(Calendar.SECOND, 0);
    c.set(Calendar.MILLISECOND, 0);

    long diff = Math.abs(c.getTimeInMillis() - target.getTimeInMillis());
    if (diff < bestDiff) {
      bestDiff = diff;
      bestIndex = i;
    }
  }

  return bestIndex;
}

PImage getBestImageForRecord(ImageRecord rec) {
  if (rec == null) return null;

  if (rec.encodedPath != null && rec.encodedPath.length() > 0) {
    PImage img = getControlImage(rec.encodedPath);
    if (img != null) return img;
  }

  if (rec.path != null && rec.path.length() > 0) {
    PImage img = getControlImage(rec.path);
    if (img != null) return img;
  }

  return null;
}

// ====================================================
// MODE ARCHIVAGE
// ====================================================
void drawArchiveMode() {
  ArrayList<ImageRecord> imgRecs = shared.getRecordsSnapshot();
  int currentIndex = shared.getCurrentIndex();

  layoutArchiveUI();

  if (archiveFlipped) {
    pushMatrix();
    translate(width, height);
    rotate(PI);
  }

  drawArchiveHeader(imgRecs.size(), currentIndex);
  drawArchiveMetaPanel(imgRecs, currentIndex);
  drawFlipButton();

  if (imgRecs.size() == 0 || currentIndex < 0 || currentIndex >= imgRecs.size()) {
    drawArchiveEmptyState();
    drawArchiveButtons(0);
    if (archiveFlipped) popMatrix();
    return;
  }

  ImageRecord currentImgRec = imgRecs.get(currentIndex);
  drawLargePlaceInteraction(currentImgRec, currentImgRec.isEditable());
  drawArchiveButtons(imgRecs.size());

  if (archiveFlipped) popMatrix();
}

void layoutArchiveUI() {
  float margin = 30;

  metaPanelW = min(390, width * 0.28);
  metaPanelX = width - margin - metaPanelW;
  metaPanelY = 160;
  metaPanelH = height - metaPanelY - 40;

  previewAreaX = 40;
  previewAreaY = 160;
  previewAreaW = metaPanelX - previewAreaX - 30;

  placeMapX = previewAreaX;
  placeMapY = previewAreaY;
  placeMapW = previewAreaW;
  placeMapH = height * 0.62;

  placeInfoX = metaPanelX + 20;
  placeInfoY = metaPanelY + 54;
  placeInfoW = metaPanelW - 40;
  placeInfoH = 70;

  sliderW = metaPanelW - 40;
  daySliderX = metaPanelX + 20;
  daySliderY = placeInfoY + placeInfoH + 36;

  monthSliderX = metaPanelX + 20;
  monthSliderY = daySliderY + 62;

  yearSliderX = metaPanelX + 20;
  yearSliderY = monthSliderY + 62;

  btnH = 88;
  btnY = height - btnH - 35;
  btnW = (previewAreaW - 30) / 2.0;
  leftBtnX = previewAreaX;
  rightBtnX = leftBtnX + btnW + 30;

  validateBtnW = 120;
  validateBtnH = 52;
  endSessionBtnW = 120;
  endSessionBtnH = 52;

  float summaryY = yearSliderY + 74;
  validateBtnX = metaPanelX + metaPanelW - 20 - validateBtnW;
  validateBtnY = summaryY + 4;

  endSessionBtnX = metaPanelX + metaPanelW - 20 - endSessionBtnW;
  endSessionBtnY = validateBtnY + validateBtnH + 14;

  flipBtnW = 150;
  flipBtnH = 44;
  flipBtnX = metaPanelX + 20;
  flipBtnY = metaPanelY + metaPanelH - flipBtnH - 16;
}

void drawArchiveHeader(int count, int currentIndex) {
  fill(C_TEXT);
  textAlign(LEFT, TOP);
  textSize(22);
  text("Mode archivage", 30, 24);

  textSize(16);
  fill(C_MUTED);
  text("Upload smartphone : http://" + localIp + ":" + serverPort, 30, 58);

  if (sessionIdentityReady) {
    fill(C_TEXT);
    text("Éducateur : " + educatorName, 30, 84);

    String pLine = "";
    for (int i = 0; i < participantCount; i++) {
      if (i > 0) pLine += " • ";
      pLine += participantNames[i];
    }
    fill(C_MUTED);
    text(pLine, 30, 108);
  }

  if (count > 0 && currentIndex >= 0) {
    fill(C_TEXT);
    text("Image " + (currentIndex + 1) + " / " + count, 30, 132);
  } else {
    fill(C_TEXT);
    text("Aucune image reçue", 30, 132);
  }

  if (millis() < flashMessageUntil && flashMessage.length() > 0) {
    fill(C_BLUE);
    text(flashMessage, 30, 156);
  }
}

void drawArchiveMetaPanel(ArrayList<ImageRecord> imgRecs, int currentIndex) {
  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.5);
  fill(C_PANEL);
  rect(metaPanelX, metaPanelY, metaPanelW, metaPanelH, 20);
  popStyle();

  fill(C_TEXT);
  textAlign(LEFT, TOP);
  textSize(22);
  text("Encodage image", metaPanelX + 20, metaPanelY + 16);

  if (imgRecs.size() == 0 || currentIndex < 0 || currentIndex >= imgRecs.size()) {
    fill(C_MUTED);
    textSize(16);
    text("Charge une image pour activer les champs.", metaPanelX + 20, metaPanelY + 60);
    return;
  }

  ImageRecord imgRec = imgRecs.get(currentIndex);
  boolean editable = imgRec.isEditable();

  fill(C_MUTED);
  textSize(16);
  text("Lieu sélectionné", metaPanelX + 20, metaPanelY + 34);
  drawSelectedPlaceInfo(imgRec);

  drawSlider("Jour", imgRec.day, 1, daysInMonth(imgRec.year, imgRec.month), daySliderX, daySliderY, sliderW, sliderH, editable);
  drawSlider("Mois", imgRec.month, 1, 12, monthSliderX, monthSliderY, sliderW, sliderH, editable);
  drawSlider("Année", imgRec.year, minYear, maxYear, yearSliderX, yearSliderY, sliderW, sliderH, editable);

  float summaryX = metaPanelX + 20;
  float summaryY = yearSliderY + 46;

  String placeText = (imgRec.placeId == 0) ? "--" : getPlaceName(imgRec.placeId);
  String dateText = nf(imgRec.day, 2) + "/" + nf(imgRec.month, 2) + "/" + imgRec.year;
  String idText = (imgRec.imageId == null || imgRec.imageId.equals("")) ? "--" : imgRec.imageId;

  fill(C_MUTED);
  textAlign(LEFT, TOP);
  textSize(16);
  text("Résumé", summaryX, summaryY);

  fill(C_TEXT);
  text("ID : " + idText, summaryX, summaryY + 26);
  text("Lieu : " + placeText, summaryX, summaryY + 52);
  text("Date : " + dateText, summaryX, summaryY + 78);
  fill(editable ? C_ORANGE : C_BLUE);
  text("État : " + (editable ? "édition" : "validée"), summaryX, summaryY + 104);

  drawValidateButton(imgRec);
  drawEndSessionButton();
}

void drawSelectedPlaceInfo(ImageRecord imgRec) {
  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.2);
  fill(255);
  rect(placeInfoX, placeInfoY, placeInfoW, placeInfoH, 14);
  popStyle();

  fill(C_TEXT);
  textAlign(LEFT, CENTER);
  textSize(18);
  String label = imgRec.placeId > 0 ? getPlaceName(imgRec.placeId) : "Aucun lieu";
  text(label, placeInfoX + 12, placeInfoY + placeInfoH / 2.0);
}

void drawLargePlaceInteraction(ImageRecord imgRec, boolean editable) {
  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.5);
  fill(255);
  rect(placeMapX, placeMapY, placeMapW, placeMapH, 20);
  popStyle();

  if (imgRec.placeId > 0) {
    PImage selected = getPlacePng(imgRec.placeId);
    if (selected != null) {
      tint(255, 120);
      drawImageContain(this, selected, placeMapX + 10, placeMapY + 10, placeMapW - 20, placeMapH - 20);
      noTint();
    }
  }

  if (placeMapImage != null && placeMapImage.width > 0) {
    tint(255, 195);
    drawImageContain(this, placeMapImage, placeMapX + 10, placeMapY + 10, placeMapW - 20, placeMapH - 20);
    noTint();
  } else {
    fill(C_MUTED);
    textAlign(CENTER, CENTER);
    textSize(20);
    text("Ajoute data/carte_lieux.png", placeMapX + placeMapW / 2.0, placeMapY + placeMapH / 2.0);
  }

  for (PlaceZone z : placeZones) {
    float px = z.px(placeMapX, placeMapW);
    float py = z.py(placeMapY, placeMapH);

    fill(C_TEXT);
    textAlign(CENTER, CENTER);
    textSize(13);
    text(z.name, px, py);
  }

  fill(C_MUTED);
  textAlign(LEFT, TOP);
  textSize(14);
  text("Clique une zone de la carte", placeMapX + 12, placeMapY + 12);
}

void drawArchiveEmptyState() {
  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.5);
  fill(255);
  rect(placeMapX, placeMapY, placeMapW, placeMapH, 20);
  popStyle();

  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(34);
  text("Aucune image", placeMapX + placeMapW / 2.0, placeMapY + placeMapH / 2.0 - 60);

  textSize(20);
  fill(C_MUTED);
  text("Ouvre cette adresse sur le téléphone :", placeMapX + placeMapW / 2.0, placeMapY + placeMapH / 2.0);

  fill(C_BLUE);
  text("http://" + localIp + ":" + serverPort, placeMapX + placeMapW / 2.0, placeMapY + placeMapH / 2.0 + 35);
}

void drawArchiveButtons(int imageCount) {
  boolean canInteract = imageCount > 1;
  boolean overLeft = isOverArchiveLeftButton();
  boolean overRight = isOverArchiveRightButton();

  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.5);
  fill(canInteract ? (overLeft ? C_BLUE_2 : color(255)) : color(245));
  rect(leftBtnX, btnY, btnW, btnH, 20);

  fill(canInteract ? (overRight ? C_BLUE_2 : color(255)) : color(245));
  rect(rightBtnX, btnY, btnW, btnH, 20);
  popStyle();

  fill(canInteract ? C_TEXT : C_MUTED);
  textAlign(CENTER, CENTER);
  textSize(36);
  text("◀", leftBtnX + btnW / 2.0, btnY + btnH / 2.0 - 6);
  text("▶", rightBtnX + btnW / 2.0, btnY + btnH / 2.0 - 6);

  fill(C_MUTED);
  textSize(18);
  text("Précédente", leftBtnX + btnW / 2.0, btnY + btnH - 18);
  text("Suivante", rightBtnX + btnW / 2.0, btnY + btnH - 18);
}

void drawValidateButton(ImageRecord imgRec) {
  String label = imgRec.getActionLabel();
  boolean over = isOverValidateButton();

  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.4);

  if (label.equals("Modifier")) fill(over ? C_BLUE : C_BLUE_2);
  else fill(over ? C_ORANGE : C_ORANGE_2);

  rect(validateBtnX, validateBtnY, validateBtnW, validateBtnH, 16);
  popStyle();

  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(21);
  text(label, validateBtnX + validateBtnW / 2.0, validateBtnY + validateBtnH / 2.0);
}

void drawEndSessionButton() {
  boolean over = isOverEndSessionButton();

  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.4);
  fill(over ? color(255, 220, 190) : C_ORANGE_2);
  rect(endSessionBtnX, endSessionBtnY, endSessionBtnW, endSessionBtnH, 16);
  popStyle();

  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(18);
  text("Fin session", endSessionBtnX + endSessionBtnW / 2.0, endSessionBtnY + endSessionBtnH / 2.0);
}

void drawFlipButton() {
  boolean over = isOverFlipButton();

  pushStyle();
  stroke(C_LINE);
  strokeWeight(1.3);
  fill(over ? C_BLUE : C_BLUE_2);
  rect(flipBtnX, flipBtnY, flipBtnW, flipBtnH, 14);
  popStyle();

  fill(C_TEXT);
  textAlign(CENTER, CENTER);
  textSize(16);
  text("Rotation 180°", flipBtnX + flipBtnW / 2.0, flipBtnY + flipBtnH / 2.0);
}

boolean isOverArchiveLeftButton() {
  float mx = archiveMouseX();
  float my = archiveMouseY();
  return mx >= leftBtnX && mx <= leftBtnX + btnW && my >= btnY && my <= btnY + btnH;
}

boolean isOverArchiveRightButton() {
  float mx = archiveMouseX();
  float my = archiveMouseY();
  return mx >= rightBtnX && mx <= rightBtnX + btnW && my >= btnY && my <= btnY + btnH;
}

boolean isOverValidateButton() {
  float mx = archiveMouseX();
  float my = archiveMouseY();
  return mx >= validateBtnX && mx <= validateBtnX + validateBtnW &&
    my >= validateBtnY && my <= validateBtnY + validateBtnH;
}

boolean isOverEndSessionButton() {
  float mx = archiveMouseX();
  float my = archiveMouseY();
  return mx >= endSessionBtnX && mx <= endSessionBtnX + endSessionBtnW &&
    my >= endSessionBtnY && my <= endSessionBtnY + endSessionBtnH;
}

boolean isOverFlipButton() {
  float mx = archiveMouseX();
  float my = archiveMouseY();
  return mx >= flipBtnX && mx <= flipBtnX + flipBtnW &&
    my >= flipBtnY && my <= flipBtnY + flipBtnH;
}

void mousePressedArchiveMode() {
  float mx = archiveMouseX();
  float my = archiveMouseY();

  if (placeMapDebug) debugPrintPlaceMapClick(mx, my);

  ArrayList<ImageRecord> imgRecs = shared.getRecordsSnapshot();
  int currentIndex = shared.getCurrentIndex();

  if (isOverFlipButton()) {
    archiveFlipped = !archiveFlipped;
    return;
  }

  if (isOverEndSessionButton()) {
    handleEndSession();
    return;
  }

  if (imgRecs.size() > 0 && currentIndex >= 0 && currentIndex < imgRecs.size()) {
    ImageRecord currentImgRec = imgRecs.get(currentIndex);

    if (isOverValidateButton()) {
      if (currentImgRec.placeId == 0) {
        flash("Choisis un lieu avant de valider");
        return;
      }

      if (!currentImgRec.validated) {
        ensureEncodedFileForCurrent();
        shared.validateCurrent();
        writeSessionTempFile();
        flash("Image validée dans la session");
      } else if (!currentImgRec.editing) {
        shared.beginEditCurrent();
        flash("Mode modification");
      } else {
        ensureEncodedFileForCurrent();
        shared.validateCurrent();
        writeSessionTempFile();
        flash("Image mise à jour");
      }
      return;
    }

    if (currentImgRec.isEditable()) {
      int placeId = getClickedArchivePlaceId(mx, my);
      if (placeId != -1) {
        shared.setPlaceForCurrent(placeId);
        return;
      }

      String sliderHit = getClickedArchiveSlider(mx, my);
      if (!sliderHit.equals("")) {
        activeSlider = sliderHit;
        updateArchiveSlider(mx);
        return;
      }
    }
  }

  if (imgRecs.size() > 1) {
    if (isOverArchiveLeftButton()) {
      shared.prev();
      return;
    }
    if (isOverArchiveRightButton()) {
      shared.next();
      return;
    }
  }
}

void mouseDraggedArchiveMode() {
  if (!activeSlider.equals("")) updateArchiveSlider(archiveMouseX());
}

void mouseReleasedArchiveMode() {
  activeSlider = "";
}

void keyPressedArchiveMode() {
  if (keyCode == LEFT) shared.prev();
  else if (keyCode == RIGHT) shared.next();
}

float archiveMouseX() {
  if (!archiveFlipped) return mouseX;
  return width - mouseX;
}

float archiveMouseY() {
  if (!archiveFlipped) return mouseY;
  return height - mouseY;
}

int getClickedArchivePlaceId(float mx, float my) {
  for (PlaceZone z : placeZones) {
    if (z.contains(mx, my, placeMapX, placeMapY, placeMapW, placeMapH)) return z.id;
  }
  return -1;
}

String getClickedArchiveSlider(float mx, float my) {
  if (mx >= daySliderX && mx <= daySliderX + sliderW && my >= daySliderY - 8 && my <= daySliderY + sliderH + 8) return "day";
  if (mx >= monthSliderX && mx <= monthSliderX + sliderW && my >= monthSliderY - 8 && my <= monthSliderY + sliderH + 8) return "month";
  if (mx >= yearSliderX && mx <= yearSliderX + sliderW && my >= yearSliderY - 8 && my <= yearSliderY + sliderH + 8) return "year";
  return "";
}

int sliderValueFromMouse(float mx, float x, float w, int minValue, int maxValue) {
  float t = constrain((mx - x) / w, 0, 1);
  return round(minValue + t * (maxValue - minValue));
}

void updateArchiveSlider(float mx) {
  ImageRecord imgRec = shared.getCurrentRecordCopy();
  if (imgRec == null || !imgRec.isEditable()) return;

  if (activeSlider.equals("day")) {
    int maxDay = daysInMonth(imgRec.year, imgRec.month);
    shared.setDayForCurrent(sliderValueFromMouse(mx, daySliderX, sliderW, 1, maxDay));
  } else if (activeSlider.equals("month")) {
    shared.setMonthForCurrent(sliderValueFromMouse(mx, monthSliderX, sliderW, 1, 12));
  } else if (activeSlider.equals("year")) {
    shared.setYearForCurrent(sliderValueFromMouse(mx, yearSliderX, sliderW, minYear, maxYear));
  }
}

// ====================================================
// OUTILS IMAGE / UI
// ====================================================
PImage getControlImage(String path) {
  if (path == null || path.length() == 0) return null;

  PImage img = controlCache.get(path);
  if (img == null) {
    img = loadImage(path);
    if (img != null && img.width > 0 && img.height > 0) {
      controlCache.put(path, img);
    } else {
      img = null;
    }
  }
  return img;
}

void drawImageContain(PApplet app, PImage img, float areaX, float areaY, float areaW, float areaH) {
  float scale = min(areaW / img.width, areaH / img.height);
  float w = img.width * scale;
  float h = img.height * scale;
  float x = areaX + (areaW - w) / 2.0;
  float y = areaY + (areaH - h) / 2.0;
  app.image(img, x, y, w, h);
}

int daysInMonth(int y, int m) {
  if (m == 2) {
    boolean leap = (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0);
    return leap ? 29 : 28;
  }
  if (m == 4 || m == 6 || m == 9 || m == 11) return 30;
  return 31;
}

boolean isOverRect(float x, float y, float w, float h) {
  return mouseX >= x && mouseX <= x + w &&
    mouseY >= y && mouseY <= y + h;
}

boolean isOverRectLocal(float px, float py, float x, float y, float w, float h) {
  return px >= x && px <= x + w &&
    py >= y && py <= y + h;
}

float portraitMouseX() {
  return mouseY;
}

float portraitMouseY() {
  return width - mouseX;
}

String findLocalIPv4() {
  try {
    Enumeration<NetworkInterface> nets = NetworkInterface.getNetworkInterfaces();
    while (nets.hasMoreElements()) {
      NetworkInterface net = nets.nextElement();
      if (!net.isUp() || net.isLoopback() || net.isVirtual()) continue;

      Enumeration<InetAddress> addrs = net.getInetAddresses();
      while (addrs.hasMoreElements()) {
        InetAddress addr = addrs.nextElement();
        String ip = addr.getHostAddress();
        if (ip.indexOf(':') == -1 && !addr.isLoopbackAddress()) return ip;
      }
    }
  }
  catch (Exception e) {
    e.printStackTrace();
  }
  return "localhost";
}

void flash(String msg) {
  flashMessage = msg;
  flashMessageUntil = millis() + 3500;
}

void debugPrintPlaceMapClick(float mx, float my) {
  if (!placeMapDebug) return;

  if (mx < placeMapX || mx > placeMapX + placeMapW ||
    my < placeMapY || my > placeMapY + placeMapH) return;

  float nx = (mx - placeMapX) / placeMapW;
  float ny = (my - placeMapY) / placeMapH;
  println("Carte click -> x=" + nf(nx, 1, 3) + "  y=" + nf(ny, 1, 3));
}

// ====================================================
// CSV
// ====================================================
String csvHeader() {
  return "educator_name;participant_1;participant_2;participant_3;participant_4;image_id;raw_path;encoded_path;place_id;place_name;day;month;year;validated";
}

String sanitizeCsv(String s) {
  if (s == null) return "";
  return s.replace(";", ",");
}

String recordToCsvLine(ImageRecord imgRec) {
  return sanitizeCsv(educatorName) + ";" +
    sanitizeCsv(participantNames[0]) + ";" +
    sanitizeCsv(participantNames[1]) + ";" +
    sanitizeCsv(participantNames[2]) + ";" +
    sanitizeCsv(participantNames[3]) + ";" +
    sanitizeCsv(imgRec.imageId) + ";" +
    sanitizeCsv(imgRec.path) + ";" +
    sanitizeCsv(imgRec.encodedPath) + ";" +
    imgRec.placeId + ";" +
    sanitizeCsv(getPlaceName(imgRec.placeId)) + ";" +
    imgRec.day + ";" +
    imgRec.month + ";" +
    imgRec.year + ";" +
    (imgRec.validated ? "1" : "0");
}

ImageRecord csvLineToRecord(String line) {
  if (line == null) return null;
  String trimmed = trim(line);
  if (trimmed.length() == 0) return null;
  if (trimmed.startsWith("educator_name;")) return null;

  String[] parts = split(trimmed, ';');
  if (parts == null) return null;

  try {
    if (parts.length >= 14) {
      String educator = parts[0];
      String p1 = parts[1];
      String p2 = parts[2];
      String p3 = parts[3];
      String p4 = parts[4];

      String imageId = parts[5];
      String rawPath = parts[6];
      String encodedPath = parts[7];
      int placeId = Integer.parseInt(parts[8]);
      int day = Integer.parseInt(parts[10]);
      int month = Integer.parseInt(parts[11]);
      int year = Integer.parseInt(parts[12]);
      int validated = Integer.parseInt(parts[13]);

      ImageRecord imgRec = new ImageRecord(rawPath, year, month, day);
      imgRec.imageId = imageId;
      imgRec.encodedPath = encodedPath;
      imgRec.placeId = placeId;
      imgRec.validated = (validated == 1);
      imgRec.editing = !imgRec.validated;
      imgRec.educatorSnapshot = educator;
      imgRec.participantSnapshot[0] = p1;
      imgRec.participantSnapshot[1] = p2;
      imgRec.participantSnapshot[2] = p3;
      imgRec.participantSnapshot[3] = p4;
      return imgRec;
    }

    if (parts.length >= 13) {
      String educator = parts[0];
      String p1 = parts[1];
      String p2 = parts[2];
      String p3 = parts[3];
      String p4 = parts[4];

      String imageId = parts[5];
      String rawPath = parts[6];
      String encodedPath = parts[7];
      int placeId = Integer.parseInt(parts[8]);
      int day = Integer.parseInt(parts[9]);
      int month = Integer.parseInt(parts[10]);
      int year = Integer.parseInt(parts[11]);
      int validated = Integer.parseInt(parts[12]);

      ImageRecord imgRec = new ImageRecord(rawPath, year, month, day);
      imgRec.imageId = imageId;
      imgRec.encodedPath = encodedPath;
      imgRec.placeId = placeId;
      imgRec.validated = (validated == 1);
      imgRec.editing = !imgRec.validated;
      imgRec.educatorSnapshot = educator;
      imgRec.participantSnapshot[0] = p1;
      imgRec.participantSnapshot[1] = p2;
      imgRec.participantSnapshot[2] = p3;
      imgRec.participantSnapshot[3] = p4;
      return imgRec;
    }
  }
  catch (Exception e) {
  }

  return null;
}

ArrayList<String> readLinesSafe(String path) {
  ArrayList<String> lines = new ArrayList<String>();
  File f = new File(path);
  if (!f.exists()) return lines;

  BufferedReader reader = null;
  try {
    reader = new BufferedReader(new InputStreamReader(new FileInputStream(f), "UTF-8"));
    String line;
    while ((line = reader.readLine()) != null) lines.add(line);
  }
  catch (Exception e) {
    e.printStackTrace();
  }
  finally {
    try {
      if (reader != null) reader.close();
    }
    catch (Exception e) {
    }
  }
  return lines;
}

boolean writeLinesSafe(String path, ArrayList<String> lines) {
  PrintWriter writer = null;
  try {
    writer = new PrintWriter(new OutputStreamWriter(new FileOutputStream(path), "UTF-8"));
    for (String line : lines) writer.println(line);
    writer.flush();
    return true;
  }
  catch (Exception e) {
    e.printStackTrace();
    return false;
  }
  finally {
    try {
      if (writer != null) writer.close();
    }
    catch (Exception e) {
    }
  }
}

void writeSessionTempFile() {
  ArrayList<String> lines = new ArrayList<String>();
  lines.add(csvHeader());

  ArrayList<ImageRecord> imgRecs = shared.getRecordsSnapshot();
  for (ImageRecord imgRec : imgRecs) {
    if (imgRec.validated) lines.add(recordToCsvLine(imgRec));
  }

  if (!writeLinesSafe(sessionTempPath, lines)) {
    flash("Erreur écriture session_temp.csv");
  }
}

void recoverSessionTempIfPresent() {
  File f = new File(sessionTempPath);
  if (!f.exists()) return;

  ArrayList<String> lines = readLinesSafe(sessionTempPath);
  int recovered = 0;
  boolean sessionNamesRecovered = false;

  for (String line : lines) {
    ImageRecord imgRec = csvLineToRecord(line);
    if (imgRec != null) {
      File rawFile = new File(imgRec.path);
      if (rawFile.exists()) {
        shared.addLoadedRecord(imgRec);
        recovered++;

        if (!sessionNamesRecovered) {
          educatorName = imgRec.educatorSnapshot;
          participantNames[0] = imgRec.participantSnapshot[0];
          participantNames[1] = imgRec.participantSnapshot[1];
          participantNames[2] = imgRec.participantSnapshot[2];
          participantNames[3] = imgRec.participantSnapshot[3];
          participantCount = inferParticipantCountFromNames(participantNames);
          sessionIdentityReady = true;
          sessionNamesRecovered = true;
        }
      }
    }
  }

  if (recovered > 0) flash(recovered + " image(s) récupérée(s) depuis la session temporaire");
}

boolean mergeTempSessionIntoMainCsv() {
  LinkedHashMap<String, String> rowsById = new LinkedHashMap<String, String>();

  ArrayList<String> mainLines = readLinesSafe(metadataCsvPath);
  for (String line : mainLines) {
    ImageRecord imgRec = csvLineToRecord(line);
    if (imgRec != null && imgRec.imageId != null && imgRec.imageId.length() > 0) {
      rowsById.put(imgRec.imageId, line);
    }
  }

  ArrayList<String> tempLines = readLinesSafe(sessionTempPath);
  int mergedCount = 0;
  for (String line : tempLines) {
    ImageRecord imgRec = csvLineToRecord(line);
    if (imgRec != null && imgRec.imageId != null && imgRec.imageId.length() > 0) {
      rowsById.put(imgRec.imageId, line);
      mergedCount++;
    }
  }

  ArrayList<String> outLines = new ArrayList<String>();
  outLines.add(csvHeader());
  for (String row : rowsById.values()) outLines.add(row);

  boolean ok = writeLinesSafe(metadataCsvPath, outLines);
  if (ok) println("Session fusionnée vers metadata.csv : " + mergedCount + " ligne(s)");
  return ok;
}

// ====================================================
// ID + COPIE ENCODÉE
// ====================================================
int readLastImageId() {
  File f = new File(idCounterPath);
  if (!f.exists()) return 0;

  ArrayList<String> lines = readLinesSafe(idCounterPath);
  if (lines.size() == 0) return 0;

  try {
    return Integer.parseInt(trim(lines.get(0)));
  }
  catch (Exception e) {
    return 0;
  }
}

void writeLastImageId(int value) {
  ArrayList<String> lines = new ArrayList<String>();
  lines.add(str(value));
  writeLinesSafe(idCounterPath, lines);
}

String generateNextImageId() {
  int lastId = readLastImageId();
  int nextId = lastId + 1;
  writeLastImageId(nextId);
  return "IMG" + nf(nextId, 6);
}

String getFileExtension(String path) {
  int dot = path.lastIndexOf('.');
  if (dot == -1) return ".jpg";
  return path.substring(dot).toLowerCase();
}

String buildEncodedFilename(ImageRecord imgRec) {
  String ext = getFileExtension(imgRec.path);
  String dateCode = nf(imgRec.day, 2) + nf(imgRec.month, 2) + nf(imgRec.year % 100, 2);
  String placeCode = "L" + nf(imgRec.placeId, 2);
  return imgRec.imageId + "_" + dateCode + "_" + placeCode + ext;
}

void ensureEncodedFileForCurrent() {
  ImageRecord imgRec = shared.getCurrentRecordReference();
  if (imgRec == null) return;

  if (imgRec.imageId == null || imgRec.imageId.equals("")) {
    imgRec.imageId = generateNextImageId();
  }

  String fileName = buildEncodedFilename(imgRec);
  File outFile = new File(encodedDir, fileName);

  try {
    if (imgRec.encodedPath != null && imgRec.encodedPath.length() > 0) {
      File oldFile = new File(imgRec.encodedPath);
      if (oldFile.exists() && !oldFile.getAbsolutePath().equals(outFile.getAbsolutePath())) {
        oldFile.delete();
      }
    }

    Files.copy(new File(imgRec.path).toPath(), outFile.toPath(), StandardCopyOption.REPLACE_EXISTING);
    imgRec.encodedPath = outFile.getAbsolutePath();
  }
  catch (Exception e) {
    e.printStackTrace();
    flash("Erreur copie image encodée");
  }
}

// ====================================================
// FIN DE SESSION
// ====================================================
void handleEndSession() {
  if (shared.getCount() == 0) {
    flash("Aucune image dans la session");
    return;
  }

  if (shared.hasUnvalidatedRecords()) {
    flash("Valide toutes les images avant de finir la session");
    return;
  }

  writeSessionTempFile();

  boolean ok = mergeTempSessionIntoMainCsv();
  if (!ok) {
    flash("Erreur fusion vers metadata.csv");
    return;
  }

  File tempFile = new File(sessionTempPath);
  if (tempFile.exists()) tempFile.delete();

  shared.clearSession();
  controlCache.clear();

  educatorName = "";
  participantNames = new String[] { "", "", "", "" };
  participantCount = 0;
  activeParticipant = -1;
  sessionIdentityReady = false;
  archiveFlipped = false;

  loadViewerRecords();

  flash("Session sauvegardée dans metadata.csv");
  currentScreen = SCREEN_MENU;
}

// ====================================================
// FERMETURE
// ====================================================
void exit() {
  if (uploadServer != null) uploadServer.shutdown();
  if (displayWindow != null) displayWindow.requestClose();
  super.exit();
}

// ====================================================
// LIEUX
// ====================================================
class PlaceZone {
  int id;
  String name;
  String pressFileBase;
  float nx, ny;
  float radiusN;

  PlaceZone(int id, String name, String pressFileBase, float nx, float ny, float radiusN) {
    this.id = id;
    this.name = name;
    this.pressFileBase = pressFileBase;
    this.nx = nx;
    this.ny = ny;
    this.radiusN = radiusN;
  }

  float px(float mapX, float mapW) {
    return mapX + nx * mapW;
  }

  float py(float mapY, float mapH) {
    return mapY + ny * mapH;
  }

  float pr(float mapW, float mapH) {
    return radiusN * min(mapW, mapH);
  }

  boolean contains(float mx, float my, float mapX, float mapY, float mapW, float mapH) {
    float dx = mx - px(mapX, mapW);
    float dy = my - py(mapY, mapH);
    float r = pr(mapW, mapH);
    return dx * dx + dy * dy <= r * r;
  }
}

void initPlaceZones() {
  placeZones.clear();

  placeZones.add(new PlaceZone( 1, "Piscine",            "1_press",  0.220, 0.237, 0.040));
  placeZones.add(new PlaceZone( 2, "Montagne",           "2_press",  0.394, 0.175, 0.040));
  placeZones.add(new PlaceZone( 3, "Forêt",              "3_press",  0.785, 0.532, 0.040));
  placeZones.add(new PlaceZone( 4, "Pouponnière",        "4_press",  0.382, 0.465, 0.040));
  placeZones.add(new PlaceZone( 5, "Administration",     "5_press",  0.250, 0.566, 0.040));
  placeZones.add(new PlaceZone( 6, "Coliou",             "6_press",  0.293, 0.721, 0.040));
  placeZones.add(new PlaceZone( 7, "Horizon",            "7_press",  0.321, 0.713, 0.040));

  placeZones.add(new PlaceZone( 8, "Escale",             "8_press",  0.347, 0.661, 0.040));
  placeZones.add(new PlaceZone( 9, "Iris",               "9_press",  0.373, 0.653, 0.040));
  placeZones.add(new PlaceZone(10, "Oustal",             "10_press", 0.382, 0.728, 0.040));
  placeZones.add(new PlaceZone(11, "SAS",                "11_press", 0.411, 0.726, 0.040));
  placeZones.add(new PlaceZone(12, "Action de santé",    "12_press", 0.453, 0.482, 0.040));
  placeZones.add(new PlaceZone(13, "Restaurant",         "13_press", 0.512, 0.564, 0.040));
  placeZones.add(new PlaceZone(14, "Buanderie",          "14_press", 0.545, 0.638, 0.040));

  placeZones.add(new PlaceZone(15, "Eclipse",            "15_press", 0.425, 0.668, 0.040));
  placeZones.add(new PlaceZone(16, "Tremplin",           "16_press", 0.472, 0.698, 0.040));
  placeZones.add(new PlaceZone(17, "Étincelle",          "17_press", 0.641, 0.592, 0.040));
  placeZones.add(new PlaceZone(18, "Équinoxe",           "18_press", 0.667, 0.586, 0.040));
  placeZones.add(new PlaceZone(19, "Appartement",        "19_press", 0.585, 0.465, 0.040));
  placeZones.add(new PlaceZone(20, "Plage",              "20_press", 0.592, 0.108, 0.040));
  placeZones.add(new PlaceZone(21, "Park attraction",    "21_press", 0.728, 0.301, 0.040));

  placeZones.add(new PlaceZone(22, "Envolée",            "22_press", 0.520, 0.750, 0.040));
  placeZones.add(new PlaceZone(23, "Passerelle",         "23_press", 0.572, 0.773, 0.040));
  placeZones.add(new PlaceZone(24, "Stade",              "24_press", 0.434, 0.777, 0.040));
  placeZones.add(new PlaceZone(25, "Espace famille",     "25_press", 0.511, 0.371, 0.040));
  placeZones.add(new PlaceZone(26, "Magasin",            "26_press", 0.489, 0.345, 0.040));
  placeZones.add(new PlaceZone(27, "Extérieur",          "27_press", 0.495, 0.889, 0.040));
}

String getPlaceName(int placeId) {
  for (PlaceZone z : placeZones) if (z.id == placeId) return z.name;
  return "--";
}

String getPlacePressFileBase(int placeId) {
  for (PlaceZone z : placeZones) if (z.id == placeId) return z.pressFileBase;
  return "";
}

PImage getPlacePng(int placeId) {
  if (placeId <= 0) return null;

  PImage img = placePngCache.get(placeId);
  if (img != null) return img;

  String base = getPlacePressFileBase(placeId);
  if (base.length() == 0) return null;

  String fileName = "places/" + base + ".png";
  img = loadImage(fileName);

  if (img != null && img.width > 0) {
    placePngCache.put(placeId, img);
    return img;
  }
  return null;
}

// ====================================================
// IMAGE RECORD
// ====================================================
class ImageRecord {
  String path;
  String imageId;
  String encodedPath;
  int placeId;
  int day;
  int month;
  int year;

  boolean validated;
  boolean editing;

  String educatorSnapshot = "";
  String[] participantSnapshot = { "", "", "", "" };

  ImageRecord(String path, int year, int month, int day) {
    this.path = path;
    this.year = year;
    this.month = month;
    this.day = day;
    this.placeId = 0;
    this.imageId = "";
    this.encodedPath = "";
    this.validated = false;
    this.editing = true;
  }

  boolean isEditable() {
    return !validated || editing;
  }

  String getActionLabel() {
    if (!validated) return "Valider";
    if (editing) return "Enregistrer";
    return "Modifier";
  }

  ImageRecord copy() {
    ImageRecord c = new ImageRecord(path, year, month, day);
    c.placeId = placeId;
    c.imageId = imageId;
    c.encodedPath = encodedPath;
    c.validated = validated;
    c.editing = editing;
    c.educatorSnapshot = educatorSnapshot;
    c.participantSnapshot[0] = participantSnapshot[0];
    c.participantSnapshot[1] = participantSnapshot[1];
    c.participantSnapshot[2] = participantSnapshot[2];
    c.participantSnapshot[3] = participantSnapshot[3];
    return c;
  }
}

// ====================================================
// ÉTAT PARTAGÉ
// ====================================================
class SharedState {
  ArrayList<ImageRecord> imgRecs = new ArrayList<ImageRecord>();
  int currentIndex = -1;

  synchronized void addImagePath(String path) {
    Calendar cal = Calendar.getInstance();
    int y = cal.get(Calendar.YEAR);
    int m = cal.get(Calendar.MONTH) + 1;
    int d = cal.get(Calendar.DAY_OF_MONTH);

    ImageRecord rec = new ImageRecord(path, y, m, d);
    rec.educatorSnapshot = educatorName;
    rec.participantSnapshot[0] = participantNames[0];
    rec.participantSnapshot[1] = participantNames[1];
    rec.participantSnapshot[2] = participantNames[2];
    rec.participantSnapshot[3] = participantNames[3];

    imgRecs.add(rec);
    currentIndex = imgRecs.size() - 1;
  }

  synchronized void addLoadedRecord(ImageRecord imgRec) {
    imgRecs.add(imgRec);
    currentIndex = imgRecs.size() - 1;
  }

  synchronized ArrayList<ImageRecord> getRecordsSnapshot() {
    ArrayList<ImageRecord> copy = new ArrayList<ImageRecord>();
    for (ImageRecord imgRec : imgRecs) copy.add(imgRec.copy());
    return copy;
  }

  synchronized int getCurrentIndex() {
    return currentIndex;
  }

  synchronized int getCount() {
    return imgRecs.size();
  }

  synchronized boolean hasUnvalidatedRecords() {
    for (ImageRecord imgRec : imgRecs) {
      if (!imgRec.validated) return true;
    }
    return false;
  }

  synchronized String getCurrentPath() {
    if (currentIndex < 0 || currentIndex >= imgRecs.size()) return null;
    return imgRecs.get(currentIndex).path;
  }

  synchronized String getCurrentDisplayPath() {
    if (currentIndex < 0 || currentIndex >= imgRecs.size()) return null;
    ImageRecord rec = imgRecs.get(currentIndex);
    if (rec.encodedPath != null && rec.encodedPath.length() > 0 && new File(rec.encodedPath).exists()) return rec.encodedPath;
    return rec.path;
  }

  synchronized ImageRecord getCurrentRecordCopy() {
    if (currentIndex < 0 || currentIndex >= imgRecs.size()) return null;
    return imgRecs.get(currentIndex).copy();
  }

  synchronized ImageRecord getCurrentRecordReference() {
    if (currentIndex < 0 || currentIndex >= imgRecs.size()) return null;
    return imgRecs.get(currentIndex);
  }

  synchronized void setCurrentIndex(int index) {
    if (index >= 0 && index < imgRecs.size()) currentIndex = index;
  }

  synchronized void prev() {
    if (imgRecs.size() <= 1) return;
    currentIndex--;
    if (currentIndex < 0) currentIndex = imgRecs.size() - 1;
  }

  synchronized void next() {
    if (imgRecs.size() <= 1) return;
    currentIndex++;
    if (currentIndex >= imgRecs.size()) currentIndex = 0;
  }

  synchronized void beginEditCurrent() {
    if (currentIndex < 0 || currentIndex >= imgRecs.size()) return;
    ImageRecord imgRec = imgRecs.get(currentIndex);
    if (imgRec.validated) imgRec.editing = true;
  }

  synchronized void validateCurrent() {
    if (currentIndex < 0 || currentIndex >= imgRecs.size()) return;
    ImageRecord imgRec = imgRecs.get(currentIndex);
    imgRec.educatorSnapshot = educatorName;
    imgRec.participantSnapshot[0] = participantNames[0];
    imgRec.participantSnapshot[1] = participantNames[1];
    imgRec.participantSnapshot[2] = participantNames[2];
    imgRec.participantSnapshot[3] = participantNames[3];
    imgRec.validated = true;
    imgRec.editing = false;
  }

  synchronized void setPlaceForCurrent(int placeId) {
    if (currentIndex < 0 || currentIndex >= imgRecs.size()) return;
    ImageRecord imgRec = imgRecs.get(currentIndex);
    if (!imgRec.isEditable()) return;
    imgRec.placeId = constrain(placeId, 1, 27);
  }

  synchronized void setDayForCurrent(int day) {
    if (currentIndex < 0 || currentIndex >= imgRecs.size()) return;
    ImageRecord imgRec = imgRecs.get(currentIndex);
    if (!imgRec.isEditable()) return;
    int maxDay = daysInMonth(imgRec.year, imgRec.month);
    imgRec.day = constrain(day, 1, maxDay);
  }

  synchronized void setMonthForCurrent(int month) {
    if (currentIndex < 0 || currentIndex >= imgRecs.size()) return;
    ImageRecord imgRec = imgRecs.get(currentIndex);
    if (!imgRec.isEditable()) return;
    imgRec.month = constrain(month, 1, 12);
    int maxDay = daysInMonth(imgRec.year, imgRec.month);
    if (imgRec.day > maxDay) imgRec.day = maxDay;
  }

  synchronized void setYearForCurrent(int yearValue) {
    if (currentIndex < 0 || currentIndex >= imgRecs.size()) return;
    ImageRecord imgRec = imgRecs.get(currentIndex);
    if (!imgRec.isEditable()) return;
    imgRec.year = constrain(yearValue, minYear, maxYear);
    int maxDay = daysInMonth(imgRec.year, imgRec.month);
    if (imgRec.day > maxDay) imgRec.day = maxDay;
  }

  synchronized void clearSession() {
    imgRecs.clear();
    currentIndex = -1;
  }
}

// ====================================================
// PATH D'AFFICHAGE COURANT POUR L'ÉCRAN PRINCIPAL
// ====================================================
String getGlobalDisplayPath() {
  if (currentScreen == SCREEN_VIEWER) {
    if (viewerCurrentIndex >= 0 && viewerCurrentIndex < viewerRecords.size()) {
      ImageRecord rec = viewerRecords.get(viewerCurrentIndex);
      if (rec.encodedPath != null && rec.encodedPath.length() > 0 && new File(rec.encodedPath).exists()) return rec.encodedPath;
      return rec.path;
    }
    return null;
  }

  if (currentScreen == SCREEN_ARCHIVE) {
    return shared.getCurrentDisplayPath();
  }

  return null;
}

// ====================================================
// FENÊTRE D'AFFICHAGE
// ====================================================
class DisplayWindow extends PApplet {
  int displayNum;

  HashMap<String, PImage> displayCache = new HashMap<String, PImage>();
  String loadedPath = null;
  PImage currentImg = null;
  volatile boolean shouldClose = false;

  DisplayWindow(int displayNum) {
    this.displayNum = displayNum;
  }

  public void settings() {
    fullScreen(displayNum);
  }

  public void setup() {
    surface.setTitle("Affichage");
    noCursor();
  }

  public void draw() {
    if (shouldClose) {
      super.exit();
      return;
    }

    background(255);

    String path = getGlobalDisplayPath();
    if (path == null) {
      fill(C_TEXT);
      textAlign(CENTER, CENTER);
      textSize(32);
      text("En attente d'image", width / 2.0, height / 2.0);
      return;
    }

    if (loadedPath == null || !loadedPath.equals(path)) {
      currentImg = getDisplayImage(path);
      loadedPath = path;
    }

    if (currentImg != null) {
      drawContain(currentImg, 0, 0, width, height);
    } else {
      fill(C_TEXT);
      textAlign(CENTER, CENTER);
      textSize(28);
      text("Image introuvable", width / 2.0, height / 2.0);
    }
  }

  PImage getDisplayImage(String path) {
    if (path == null) return null;

    PImage img = displayCache.get(path);
    if (img == null) {
      img = loadImage(path);
      if (img != null && img.width > 0 && img.height > 0) {
        displayCache.put(path, img);
      } else {
        img = null;
      }
    }
    return img;
  }

  void drawContain(PImage img, float areaX, float areaY, float areaW, float areaH) {
    float scale = min(areaW / img.width, areaH / img.height);
    float w = img.width * scale;
    float h = img.height * scale;
    float x = areaX + (areaW - w) / 2.0;
    float y = areaY + (areaH - h) / 2.0;
    image(img, x, y, w, h);
  }

  void requestClose() {
    shouldClose = true;
  }
}

// ====================================================
// SERVEUR UPLOAD
// ====================================================
class UploadServer extends Thread {
  int port;
  String uploadsDir;
  SharedState shared;

  ServerSocket serverSocket;
  volatile boolean running = true;

  UploadServer(int port, String uploadsDir, SharedState shared) {
    this.port = port;
    this.uploadsDir = uploadsDir;
    this.shared = shared;
  }

  public void run() {
    try {
      serverSocket = new ServerSocket(port);
      while (running) {
        Socket client = serverSocket.accept();
        new ClientHandler(client, uploadsDir, shared).start();
      }
    }
    catch (Exception e) {
      if (running) e.printStackTrace();
    }
  }

  void shutdown() {
    running = false;
    try {
      if (serverSocket != null) serverSocket.close();
    }
    catch (Exception e) {
    }
  }
}

class ClientHandler extends Thread {
  Socket socket;
  String uploadsDir;
  SharedState shared;

  ClientHandler(Socket socket, String uploadsDir, SharedState shared) {
    this.socket = socket;
    this.uploadsDir = uploadsDir;
    this.shared = shared;
  }

  public void run() {
    try {
      InputStream in = socket.getInputStream();
      OutputStream out = socket.getOutputStream();

      String requestLine = readLine(in);
      if (requestLine == null || requestLine.length() == 0) {
        socket.close();
        return;
      }

      HashMap<String, String> headers = new HashMap<String, String>();
      String line;
      while ((line = readLine(in)) != null) {
        if (line.length() == 0) break;
        int idx = line.indexOf(':');
        if (idx > 0) {
          String key = line.substring(0, idx).trim().toLowerCase();
          String value = line.substring(idx + 1).trim();
          headers.put(key, value);
        }
      }

      String[] parts = requestLine.split(" ");
      if (parts.length < 2) {
        sendText(out, 400, "Bad Request");
        socket.close();
        return;
      }

      String method = parts[0];
      String target = parts[1];

      if (method.equals("GET") && target.equals("/")) {
        sendHtml(out, buildUploadPage());
      } else if (method.equals("POST") && target.startsWith("/upload")) {
        handleUpload(out, in, target, headers);
      } else {
        sendText(out, 404, "Not Found");
      }

      out.flush();
      socket.close();
    }
    catch (Exception e) {
      e.printStackTrace();
      try {
        socket.close();
      }
      catch (Exception ex) {
      }
    }
  }

  void handleUpload(OutputStream out, InputStream in, String target, HashMap<String, String> headers) throws Exception {
    String contentType = headers.get("content-type");
    String contentLengthStr = headers.get("content-length");

    if (contentType == null || !contentType.startsWith("image/")) {
      sendText(out, 400, "Le fichier doit être une image");
      return;
    }

    if (contentLengthStr == null) {
      sendText(out, 411, "Content-Length manquant");
      return;
    }

    int contentLength = Integer.parseInt(contentLengthStr);
    byte[] body = readBytes(in, contentLength);

    String query = "";
    int q = target.indexOf('?');
    if (q >= 0 && q < target.length() - 1) query = target.substring(q + 1);

    String fileName = extractFileName(query, contentType);
    File outFile = makeUniqueFile(new File(uploadsDir), fileName);

    Files.write(outFile.toPath(), body);
    shared.addImagePath(outFile.getAbsolutePath());

    sendText(out, 200, "Image reçue : " + outFile.getName());
  }

  String buildUploadPage() {
    return ""
      + "<!doctype html>"
      + "<html lang='fr'>"
      + "<head>"
      + "  <meta charset='utf-8'>"
      + "  <meta name='viewport' content='width=device-width,initial-scale=1'>"
      + "  <title>Envoyer des images</title>"
      + "  <style>"
      + "    body { font-family: system-ui, sans-serif; background:#ffffff; color:#222; margin:0; padding:24px; }"
      + "    .wrap { max-width:560px; margin:0 auto; }"
      + "    .card { background:#f8f8f8; border:1px solid #ddd; border-radius:14px; padding:18px; margin-top:18px; }"
      + "    input[type=file] { display:block; width:100%; margin-bottom:14px; font-size:16px; }"
      + "    button { background:#0078ff; color:white; border:none; border-radius:10px; padding:14px 18px; font-size:16px; width:100%; }"
      + "    #status { margin-top:16px; white-space:pre-line; color:#166534; }"
      + "  </style>"
      + "</head>"
      + "<body>"
      + "  <div class='wrap'>"
      + "    <h1>Envoyer des images vers Processing</h1>"
      + "    <p>Choisis une ou plusieurs images, puis appuie sur “Téléverser”.</p>"
      + "    <div class='card'>"
      + "      <input id='files' type='file' accept='image/*' multiple>"
      + "      <button id='send'>Téléverser</button>"
      + "      <div id='status'>Aucune image envoyée.</div>"
      + "    </div>"
      + "  </div>"
      + "  <script>"
      + "    const input = document.getElementById('files');"
      + "    const button = document.getElementById('send');"
      + "    const status = document.getElementById('status');"
      + "    button.onclick = async () => {"
      + "      const files = [...input.files];"
      + "      if (!files.length) {"
      + "        status.textContent = 'Choisis au moins une image.';"
      + "        return;"
      + "      }"
      + "      button.disabled = true;"
      + "      status.textContent = `Envoi de ${files.length} image(s)...`;"
      + "      let ok = 0;"
      + "      let fail = 0;"
      + "      for (const file of files) {"
      + "        try {"
      + "          const safeName = encodeURIComponent(file.name || ('image_' + Date.now() + '.jpg'));"
      + "          const res = await fetch(`/upload?name=${safeName}`, {"
      + "            method: 'POST',"
      + "            headers: { 'Content-Type': file.type || 'application/octet-stream' },"
      + "            body: file"
      + "          });"
      + "          if (res.ok) ok++; else fail++;"
      + "        } catch (e) { fail++; }"
      + "      }"
      + "      status.textContent = `Terminé.\\nRéussies : ${ok}\\nÉchecs : ${fail}`;"
      + "      input.value = '';"
      + "      button.disabled = false;"
      + "    };"
      + "  </script>"
      + "</body>"
      + "</html>";
  }

  String readLine(InputStream in) throws IOException {
    ByteArrayOutputStream buffer = new ByteArrayOutputStream();
    int c;
    boolean gotCR = false;

    while ((c = in.read()) != -1) {
      if (c == '\r') {
        gotCR = true;
        continue;
      }
      if (c == '\n') break;
      if (gotCR) {
        buffer.write('\r');
        gotCR = false;
      }
      buffer.write(c);
    }

    if (c == -1 && buffer.size() == 0) return null;
    return buffer.toString("UTF-8");
  }

  byte[] readBytes(InputStream in, int length) throws IOException {
    byte[] data = new byte[length];
    int total = 0;
    while (total < length) {
      int n = in.read(data, total, length - total);
      if (n == -1) break;
      total += n;
    }
    if (total == length) return data;
    return Arrays.copyOf(data, total);
  }

  void sendHtml(OutputStream out, String html) throws IOException {
    byte[] body = html.getBytes(StandardCharsets.UTF_8);
    String headers =
      "HTTP/1.1 200 OK\r\n" +
      "Content-Type: text/html; charset=utf-8\r\n" +
      "Content-Length: " + body.length + "\r\n" +
      "Connection: close\r\n\r\n";
    out.write(headers.getBytes(StandardCharsets.UTF_8));
    out.write(body);
  }

  void sendText(OutputStream out, int code, String msg) throws IOException {
    String status = "OK";
    if (code == 400) status = "Bad Request";
    else if (code == 404) status = "Not Found";
    else if (code == 405) status = "Method Not Allowed";
    else if (code == 411) status = "Length Required";
    else if (code == 500) status = "Internal Server Error";

    byte[] body = msg.getBytes(StandardCharsets.UTF_8);
    String headers =
      "HTTP/1.1 " + code + " " + status + "\r\n" +
      "Content-Type: text/plain; charset=utf-8\r\n" +
      "Content-Length: " + body.length + "\r\n" +
      "Connection: close\r\n\r\n";
    out.write(headers.getBytes(StandardCharsets.UTF_8));
    out.write(body);
  }

  String extractFileName(String query, String contentType) {
    String defaultExt = extensionFromContentType(contentType);
    String fallback = "image_" + System.currentTimeMillis() + defaultExt;

    if (query == null || !query.startsWith("name=")) return fallback;

    try {
      String raw = query.substring(5);
      String decoded = URLDecoder.decode(raw, "UTF-8");
      decoded = decoded.replaceAll("[^a-zA-Z0-9._-]", "_");

      if (decoded.trim().length() == 0) return fallback;
      if (!decoded.contains(".")) decoded += defaultExt;
      return decoded;
    }
    catch (Exception e) {
      return fallback;
    }
  }

  String extensionFromContentType(String contentType) {
    if (contentType == null) return ".jpg";
    if (contentType.equals("image/png")) return ".png";
    if (contentType.equals("image/gif")) return ".gif";
    if (contentType.equals("image/webp")) return ".webp";
    if (contentType.equals("image/jpeg")) return ".jpg";
    if (contentType.equals("image/heic")) return ".heic";
    return ".jpg";
  }

  File makeUniqueFile(File dir, String name) {
    File f = new File(dir, name);
    if (!f.exists()) return f;

    int dot = name.lastIndexOf('.');
    String base = (dot >= 0) ? name.substring(0, dot) : name;
    String ext = (dot >= 0) ? name.substring(dot) : "";
    return new File(dir, base + "_" + System.currentTimeMillis() + ext);
  }
}
