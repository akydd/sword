/***************************************************************************
                          GBFWEBIF.cpp  -   GBF to HTML filter with hrefs 
			        for strongs and morph tags
                             -------------------
    begin                    : 2001-09-03
    copyright            : 2001 by CrossWire Bible Society
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/

#include <gbfwebif.h>
#include <ctype.h>
#include <utilweb.h>

SWORD_NAMESPACE_START

GBFWEBIF::GBFWEBIF() : baseURL("/"), passageStudyURL(baseURL + "passagestudy.jsp") {
//all is done in GBFHTMLHREF since it inherits form this class
}

bool GBFWEBIF::handleToken(SWBuf &buf, const char *token, DualStringMap &userData) {
	const char *tok;
	char val[128];
	char *valto;
	const char *num;
	std::string url;

	if (!substituteToken(buf, token)) {
		if (!strncmp(token, "w", 1)) {
			// OSIS Word (temporary until OSISRTF is done)
			valto = val;
			num = strstr(token, "lemma=\"x-Strongs:");

			if (num) {
				for (num+=17; ((*num) && (*num != '\"')); num++)
					*valto++ = *num;
				*valto = 0;

				if (atoi((!isdigit(*val))?val+1:val) < 5627) {
					buf += " <small><em>&lt;";
					url = "";
					for (tok = val; *tok; tok++) {
						url += *tok;
					}
					buf.appendFormatted("<a href=\"%s?key=%s\">", passageStudyURL.c_str(), encodeURL(url).c_str());

					for (tok = (!isdigit(*val))?val+1:val; *tok; tok++) {
						buf += *tok;
					}
					buf += "</a>&gt;</em></small> ";
				}
			}
			valto = val;
			num = strstr(token, "morph=\"x-Robinson:");
			if (num) {
				for (num+=18; ((*num) && (*num != '\"')); num++)
					*valto++ = *num;
				*valto = 0;
				buf += " <small><em>(";
				url = "";
				for (tok = val; *tok; tok++) {
				// normal robinsons tense
					buf += *tok;
				}
				buf.appendFormatted("<a href=\"%s?key=%s\">", passageStudyURL.c_str(), encodeURL(url).c_str());

				for (tok = val; *tok; tok++) {
					buf += *tok;
				}
				buf += "</a>)</em></small> ";
			}
		}

		else if (!strncmp(token, "WG", 2) || !strncmp(token, "WH", 2)) { // strong's numbers
			buf += " <small><em>&lt;";
			url = "";

			for (tok = token+1; *tok; tok++) {
				url += *tok;
			}
			buf.appendFormatted("<a href=\"%s?key=%s\">", passageStudyURL.c_str(), encodeURL(url).c_str());

			for (tok = token + 2; *tok; tok++) {
				buf += *tok;
			}
			buf += "</a>&gt;</em></small>";
		}

		else if (!strncmp(token, "WTG", 3) || !strncmp(token, "WTH", 3)) { // strong's numbers tense
			buf += " <small><em>(";
			url = "";
			for (tok = token + 2; *tok; tok++) {
				if(*tok != '\"')
					url += *tok;
			}
			buf.appendFormatted("<a href=\"%s?key=%s\">", passageStudyURL.c_str(), encodeURL(url).c_str());

			for (tok = token + 3; *tok; tok++)
				if(*tok != '\"')
					buf += *tok;
			buf += "</a>)</em></small>";
		}

		else if (!strncmp(token, "WT", 2) && strncmp(token, "WTH", 3) && strncmp(token, "WTG", 3)) { // morph tags
			buf += " <small><em>(";
			for (tok = token + 2; *tok; tok++) {
				if(*tok != '\"')
					buf += *tok;
			}
			buf.appendFormatted("<a href=\"%s?key=%s\">", passageStudyURL.c_str(), encodeURL(url).c_str());

			for (tok = token + 2; *tok; tok++) {
				if(*tok != '\"')
					buf += *tok;
			}
			buf += "</a>)</em></small>";
		}

		else if (!strncmp(token, "RX", 2)) {
			buf += "<a href=\"";
			for (tok = token + 3; *tok; tok++) {
			  if(*tok != '<' && *tok+1 != 'R' && *tok+2 != 'x') {
			    buf += *tok;
			  }
			  else {
			    break;
			  }
			}

			buf.appendFormatted("a href=\"%s?key=%s\">", passageStudyURL.c_str(), encodeURL(url).c_str());
		}

		else {
			return GBFHTMLHREF::handleToken(buf, token, userData);
		}
	}
	return true;
}

SWORD_NAMESPACE_END