/******************************************************************************
 *  ztext.cpp - code for class 'zText'- a module that reads compressed text
 *				files: ot and nt using indexs ??.vss
 */


#include <ctype.h>
#include <stdio.h>
#include <fcntl.h>

#ifndef __GNUC__
#include <io.h>
#else
#include <unistd.h>
#endif

#include <string.h>
#include <utilfuns.h>
//#include <rawverse.h>
#include <ztext.h>
//#include <zlib.h>

SWORD_NAMESPACE_START

/******************************************************************************
 * zText Constructor - Initializes data for instance of zText
 *
 * ENT:	ipath - path to data files
 *		iname - Internal name for module
 *		idesc - Name to display to user for module
 *		iblockType - verse, chapter, book, etc. of index chunks
 *		icomp - Compressor object
 *		idisp - Display object to use for displaying
 */

zText::zText(const char *ipath, const char *iname, const char *idesc, int iblockType, SWCompress *icomp, SWDisplay *idisp, SWTextEncoding enc, SWTextDirection dir, SWTextMarkup mark, const char* ilang)
		: zVerse(ipath, -1, iblockType, icomp), SWText(iname, idesc, idisp, enc, dir, mark, ilang) {
	blockType = iblockType;
	lastWriteKey = 0;
}


/******************************************************************************
 * zText Destructor - Cleans up instance of zText
 */

zText::~zText()
{
	flushCache();

	if (lastWriteKey)
		delete lastWriteKey;
}


/******************************************************************************
 * zText::getRawEntry	- Returns the current verse buffer
 *
 * RET: buffer with verse
 */

SWBuf &zText::getRawEntryBuf() {
	long  start = 0;
	unsigned short size = 0;
	VerseKey &key = getVerseKey();

	findOffset(key.Testament(), key.Index(), &start, &size);
	entrySize = size;        // support getEntrySize call
			  
	entryBuf = "";
	zReadText(key.Testament(), start, size, entryBuf);

	rawFilter(entryBuf, &key);

	if (!isUnicode())
		prepText(entryBuf);

	return entryBuf;
}


bool zText::sameBlock(VerseKey *k1, VerseKey *k2) {
	if (k1->Testament() != k2->Testament())
		return false;

	switch (blockType) {
	case VERSEBLOCKS:
		if (k1->Verse() != k2->Verse())
			return false;
	case CHAPTERBLOCKS:
		if (k1->Chapter() != k2->Chapter())
			return false;
	case BOOKBLOCKS:
		if (k1->Book() != k2->Book())
			return false;
	}
	return true;
}


void zText::setEntry(const char *inbuf, long len) {
	VerseKey &key = getVerseKey();

	// see if we've jumped across blocks since last write
	if (lastWriteKey) {
		if (!sameBlock(lastWriteKey, &key)) {
			flushCache();
		}
		delete lastWriteKey;
	}

	doSetText(key.Testament(), key.Index(), inbuf, len);

	lastWriteKey = (VerseKey *)key.clone();	// must delete
}


void zText::linkEntry(const SWKey *inkey) {
	VerseKey &destkey = getVerseKey();
	const VerseKey *srckey = 0;

	// see if we have a VerseKey * or decendant
	try {
		srckey = (const VerseKey *) SWDYNAMIC_CAST(VerseKey, inkey);
	}
	catch ( ... ) {
	}
	// if we don't have a VerseKey * decendant, create our own
	if (!srckey)
		srckey = new VerseKey(inkey);

	doLinkEntry(destkey.Testament(), destkey.Index(), srckey->Index());

	if (inkey != srckey) // free our key if we created a VerseKey
		delete srckey;
}


/******************************************************************************
 * zFiles::deleteEntry	- deletes this entry
 *
 */

void zText::deleteEntry() {

	VerseKey &key = getVerseKey();

	doSetText(key.Testament(), key.Index(), "");
}


/******************************************************************************
 * zText::increment	- Increments module key a number of entries
 *
 * ENT:	increment	- Number of entries to jump forward
 *
 */

void zText::increment(int steps) {
	long  start;
	unsigned short size;
	VerseKey *tmpkey = &getVerseKey();

	findOffset(tmpkey->Testament(), tmpkey->Index(), &start, &size);

	SWKey lastgood = *tmpkey;
	while (steps) {
		long laststart = start;
		unsigned short lastsize = size;
		SWKey lasttry = *tmpkey;
		(steps > 0) ? (*key)++ : (*key)--;
		tmpkey = &getVerseKey();

		if ((error = key->Error())) {
			*key = lastgood;
			break;
		}
		long index = tmpkey->Index();
		findOffset(tmpkey->Testament(), index, &start, &size);

		if (
			(((laststart != start) || (lastsize != size))	// we're a different entry
//				&& (start > 0)
				&& (size))	// and we actually have a size
				||(!skipConsecutiveLinks)) {	// or we don't want to skip consecutive links
			steps += (steps < 0) ? 1 : -1;
			lastgood = *tmpkey;
		}
	}
	error = (error) ? KEYERR_OUTOFBOUNDS : 0;
}


VerseKey &zText::getVerseKey() {
	static VerseKey tmpVK;
	VerseKey *key;
	// see if we have a VerseKey * or decendant
	try {
		key = SWDYNAMIC_CAST(VerseKey, this->key);
	}
	catch ( ... ) {	}
	if (!key) {
		ListKey *lkTest = 0;
		try {
			lkTest = SWDYNAMIC_CAST(ListKey, this->key);
		}
		catch ( ... ) {	}
		if (lkTest) {
			try {
				key = SWDYNAMIC_CAST(VerseKey, lkTest->GetElement());
			}
			catch ( ... ) {	}
		}
	}
	if (!key) {
		tmpVK = *(this->key);
		return tmpVK;
	}
	else	return *key;
}


SWORD_NAMESPACE_END
