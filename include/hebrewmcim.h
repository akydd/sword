#ifndef HEBREWMCIM_H
#define HEBREWMCIM_H

/**
 * Title: Keyboard mapping for Michigan-Claremont Hebrew input
 * Description:
 * Copyright:    Copyright (c) 2001 CrossWire Bible Society under the terms of the GNU GPL
 * Company:
 * @author Troy A. Griffitts
 * @version 1.0
 */

#include <swinputmeth.h>
#include <map>

class HebrewMCIM : public SWInputMethod {

    void init();
    char subst[255];
    map<int, int> subst2[12];
    map<int, int*> multiChars;

public:
    HebrewMCIM();
    int *translate(char in);
};

#endif
