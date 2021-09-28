/**
 * Map vetoing functions
 */
public void CreateMapVeto() {
  if (GetConVarInt(g_RandomizeMapOrderCvar) != 0) {
    RandomizeArray(g_MapList);
  }

  ClearArray(g_MapVetoed);
  for (int i = 0; i < g_MapList.Length; i++) {
    g_MapVetoed.Push(false);
  }

  GiveVetoMenu(g_capt1);
}

public void CreateSeriesVote() {
  if (GetConVarInt(g_RandomizeMapOrderCvar) != 0) {
    RandomizeArray(g_MapList);
  }

  ClearArray(g_MapVetoed);
  ClearArray(g_MapPicked);
  seriesVoteIndex = 0;
  for (int i = 0; i < g_MapList.Length; i++) {
    g_MapVetoed.Push(false);
    g_MapPicked.Push(false);
  }

  GiveSeriesMenu(GetVoterCaptain(g_capt1));
}

public void GiveVetoMenu(int client) {
  Menu menu = new Menu(VetoHandler);
  menu.ExitButton = false;
  menu.SetTitle("%T", "VetoMenuTitle", client);

  for (int i = 0; i < g_MapList.Length; i++) {
    if (!g_MapVetoed.Get(i)) {
      AddMapIndexToMenu(menu, g_MapList, i);
    }
  }
  DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public void GiveSeriesMenu(int client) {
  Menu menu = new Menu(SeriesHandler);
  menu.ExitButton = false;
  char voteType = GetCurrentVoteType();
  
  if (voteType == 'p') {
    // Pick
    menu.SetTitle("%T", "VoteMenuTitle", client);
  } else if (voteType == 'b') {
    // Ban/Veto
    menu.SetTitle("%T", "VetoMenuTitle", client);
  }

  if (voteType != 'r') {
    for (int i = 0; i < g_MapList.Length; i++) {
      if (!g_MapVetoed.Get(i) && !g_MapPicked.Get(i)) {
        AddMapIndexToMenu(menu, g_MapList, i);
      }
    }
    DisplayMenu(menu, client, MENU_TIME_FOREVER);
  } else {
    ArrayList mapPool = new ArrayList();
    for (int i = 0; i < g_MapList.Length; i++) {
      if (!g_MapVetoed.Get(i) && !g_MapPicked.Get(i)) {
        mapPool.Push(i);
      }
    }
    // Choose random
    RandomizeArray(mapPool);
    char map[PLATFORM_MAX_PATH];
    FormatMapName(g_MapList, mapPool.Get(0), map, sizeof(map));
    PugSetup_MessageToAll("{LIGHT_RED}%s{NORMAL} wurde zufällig gewählt.", map);
    g_MapPicked.Set(mapPool.Get(0), true);
    seriesMaps.Push(mapPool.Get(0));
    
    seriesVoteIndex++;
    int next = GetVoterCaptain(client);
    if (next == -1) {
      FinishSeriesVote();
      return;
    } 
    // TODO: Remove following line
    next = client;
    
    GiveSeriesMenu(next);
  }
}

static int GetNumMapsLeft() {
  int count = 0;
  for (int i = 0; i < g_MapList.Length; i++) {
    if (!g_MapVetoed.Get(i))
      count++;
  }
  return count;
}

static int GetFirstMapLeft() {
  for (int i = 0; i < g_MapList.Length; i++) {
    if (!g_MapVetoed.Get(i))
      return i;
  }
  return -1;
}

public int SeriesHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    int index = GetMenuInt(menu, param2);
    char map[PLATFORM_MAX_PATH];
    FormatMapName(g_MapList, index, map, sizeof(map));
    char voteType = GetCurrentVoteType();

    char captString[64];
    FormatPlayerName(client, client, captString);
    if (voteType == 'p') {
      char mapColor[PLATFORM_MAX_PATH] = "{LIGHT_RED}";
      StrCat(mapColor, PLATFORM_MAX_PATH, map);
      PugSetup_MessageToAll("%t", "PlayerPickChoice", captString, mapColor);
      g_MapPicked.Set(index, true);
      seriesMaps.Push(index);
    } else if (voteType == 'b') {
      PugSetup_MessageToAll("%t", "PlayerVetoed", captString, map);
      g_MapVetoed.Set(index, true);
    }

    seriesVoteIndex++;
    if (GetNumMapsLeft() == 1) {
      // ChangeMap(g_MapList, GetFirstMapLeft());
    } else {
      int next = GetVoterCaptain(client);
      if (next == -1) {
        FinishSeriesVote();
        return;
      }

      // TODO: Remove following line
      next = client;

      GiveSeriesMenu(next);
      for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && i != next) {
          VetoStatusDisplay(i);
        }
      }
    }

  } else if (action == MenuAction_End) {
    CloseHandle(menu);
  }
}

public int VetoHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_Select) {
    int client = param1;
    int index = GetMenuInt(menu, param2);
    char map[PLATFORM_MAX_PATH];
    FormatMapName(g_MapList, index, map, sizeof(map));

    char captString[64];
    FormatPlayerName(client, client, captString);
    PugSetup_MessageToAll("%t", "PlayerVetoed", captString, map);

    g_MapVetoed.Set(index, true);
    if (GetNumMapsLeft() == 1) {
      ChangeMap(g_MapList, GetFirstMapLeft());
    } else {
      int other = OtherCaptain(client);
      GiveVetoMenu(other);
      for (int i = 1; i <= MaxClients; i++) {
        if (IsPlayer(i) && i != other) {
          VetoStatusDisplay(i);
        }
      }
    }

  } else if (action == MenuAction_End) {
    CloseHandle(menu);
  }
}

static void VetoStatusDisplay(int client) {
  Menu menu = new Menu(VetoStatusHandler);
  SetMenuExitButton(menu, true);
  SetMenuTitle(menu, "%T", "MapsLeft", client);
  for (int i = 0; i < g_MapList.Length; i++) {
    if (!g_MapVetoed.Get(i)) {
      AddMapIndexToMenu(menu, g_MapList, i, true);
    }
  }
  DisplayMenu(menu, client, 30);
}

static void SeriesStatusDisplay(int client) {
  Menu menu = new Menu(SeriesStatusHandler);
  SetMenuExitButton(menu, true);
  SetMenuTitle(menu, "%T", "MapsLeft", client);
  for (int i = 0; i < g_MapList.Length; i++) {
    if (!g_MapVetoed.Get(i) && !g_MapPicked.Get(i)) {
      AddMapIndexToMenu(menu, g_MapList, i, true);
    }
  }
  DisplayMenu(menu, client, 30);
}

public int VetoStatusHandler(Menu menu, MenuAction action, int param1, int param2) {
  if (action == MenuAction_End) {
    CloseHandle(menu);
  }
}

public char GetCurrentVoteType() {
  if (bestOfX == 3) {
    if (seriesVoteTypeBo3[seriesVoteIndex] == 'b') {
      return 'b';
    } else if (seriesVoteTypeBo3[seriesVoteIndex] == 'p') {
      return 'p';
    } else {
      return 'r';
    }
  } else if (bestOfX == 5) {
    if (seriesVoteTypeBo5[seriesVoteIndex] == 'b') {
      return 'b';
    } else if (seriesVoteTypeBo5[seriesVoteIndex] == 'p') {
      return 'p';
    } else {
      return 'r';
    }
  }
  return 'b';
}

public int GetVoterCaptain(int current) {
  if (bestOfX == 3) {
    if (seriesVoteIndex > strlen(seriesVoteTeamBo3) - 1) {
      return -1;
    }
    if (seriesVoteTeamBo3[seriesVoteIndex] == '1') {
      return g_capt1;
    } else if (seriesVoteTeamBo3[seriesVoteIndex] == '2') {
      // TODO: remove following line
      return g_capt1;
      // return g_capt2;
    } else {
      return 100;
    }
  } else if (bestOfX == 5) {
    if (seriesVoteIndex > strlen(seriesVoteTeamBo5) - 1) {
      return -1;
    }
    if (seriesVoteTeamBo5[seriesVoteIndex] == '1') {
      return g_capt1;
    } else if (seriesVoteTeamBo5[seriesVoteIndex] == '2') {
      // TODO: remove following line
      return g_capt1;
      // return g_capt2;
    } else {
      return 100;
    }
  } else {
    return OtherCaptain(current);
  }
}

public void FinishSeriesVote() {
  // if (bestOfX == 3) {
  //   char map1[PLATFORM_MAX_PATH];
  //   g_MapList.GetString(seriesMaps.Get(0), map1, sizeof(map1));
  //   char map2[PLATFORM_MAX_PATH];
  //   g_MapList.GetString(seriesMaps.Get(1), map2, sizeof(map2));
  //   char map3[PLATFORM_MAX_PATH];
  //   g_MapList.GetString(seriesMaps.Get(2), map3, sizeof(map3));
  //   PugSetup_MessageToAll("{LIGHT_BLUE}BO3: {LIGHT_RED}%s{NORMAL}, {LIGHT_RED}%s{NORMAL}, {LIGHT_RED}%s{NORMAL}", 
  //     map1, 
  //     map2, 
  //     map3);
  // } else if (bestOfX == 5) {
  //   char map1[PLATFORM_MAX_PATH];
  //   g_MapList.GetString(seriesMaps.Get(0), map1, sizeof(map1));
  //   char map2[PLATFORM_MAX_PATH];
  //   g_MapList.GetString(seriesMaps.Get(1), map2, sizeof(map2));
  //   char map3[PLATFORM_MAX_PATH];
  //   g_MapList.GetString(seriesMaps.Get(2), map3, sizeof(map3));
  //   char map4[PLATFORM_MAX_PATH];
  //   g_MapList.GetString(seriesMaps.Get(3), map4, sizeof(map4));
  //   char map5[PLATFORM_MAX_PATH];
  //   g_MapList.GetString(seriesMaps.Get(4), map5, sizeof(map5));
  //   PugSetup_MessageToAll("{LIGHT_BLUE}BO5: {LIGHT_RED}%s{NORMAL}, {LIGHT_RED}%s{NORMAL}, {LIGHT_RED}%s{NORMAL}, {LIGHT_RED}%s{NORMAL}, {LIGHT_RED}%s{NORMAL}", 
  //   map1, 
  //   map2, 
  //   map3, 
  //   map4, 
  //   map5);
  // }
}