%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>
#include <string>
#include <algorithm>
#include <vector>
#include <map>

using namespace std;
#define yylval cool_yylval
#define yylex  cool_yylex

#define MAX_STR_CONST 1025
#define YY_NO_UNPUT

extern FILE *fin;

#undef YY_INPUT
#define YY_INPUT(buf,sourceult,max_size) \
	if((sourceult = fread((char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR("read() in flex scanner failed");

char string_buf[MAX_STR_CONST];
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;
extern YYSTYPE cool_yylval;

int comment_depth = 0;
vector<std::string> lines_holder;
size_t num_of_ending_backslashes(string, size_t);
int handle_string(string);
bool string_contains_null(string, size_t);

%}

DARROW    =>
ASSIGN    <-
LE        <=
DIGIT    [0-9]
LC_LETTERS [a-z]
UP_LETTERS [A-Z]
FALSE	 (?i:false)
TRUE	 (?i:true)
CLASS    (?i:class)
ESAC     (?i:esac)
ELSE     (?i:else)
FI	 (?i:fi)
IF	 (?i:if)
IN	 (?i:in)
INHERITS (?i:inherits)
ISVOID	 (?i:isvoid)
LET	 (?i:let)
LOOP	 (?i:loop)
POOL	 (?i:pool)
THEN	 (?i:then)
WHILE	 (?i:while)
CASE	 (?i:case)
NEW	 (?i:new)
OF	 (?i:of)
NOT	 (?i:not)
WHITESPACE		[ \t\r\f\v]+
TYPEID   [A-Z][A-Za-z0-9_]*
OBJECTID [a-z][A-Za-z0-9_]*
MISC	 [+\-*\/<=\.(){}~@:;,]
%x COMMENT
%x DDCOMMENT
%x LINE_BREAKING
%s STRING_START
STRING \"([^"\n\\]|\\.)*\"
STARTING_LINE \"([^\n\"\\]|\\.)+(\\)*(\n)*
STARTING_LINE_SECOND_TYPE ([^\n\\"]|\\.)*(\\)(\\)*(\n)*
UNQUOTED_STRING ([^\n\\]|\\.)*
ENDING_LINE ([^\n\\]|\\.)*\"$
NEWLINE \n

%%

{DARROW}	        { return (DARROW); }
{ASSIGN}		{ return ASSIGN; }
{LE}			{ return LE; }

{DIGIT}+ {
    cool_yylval.symbol = inttable.add_string(yytext);
    return INT_CONST;
}

"(*" { BEGIN(COMMENT); comment_depth = 0; }
<COMMENT>"(*" { comment_depth++; }
<COMMENT>"*)" { 
     if(comment_depth == 0) BEGIN(INITIAL); 
     else comment_depth--; }

"*)" { 
       cool_yylval.error_msg = "Unmatched *)";
       return ERROR;
 }

<COMMENT>\n   { curr_lineno++; }
<COMMENT>.    { }
<COMMENT><<EOF>> {
  BEGIN(INITIAL);
  cool_yylval.error_msg = "EOF in comment";
  return ERROR;
}

"--" { BEGIN(DDCOMMENT); }
<DDCOMMENT>\n { curr_lineno++; BEGIN(INITIAL); }
<DDCOMMENT>.    { }

<LINE_BREAKING>{ENDING_LINE} {
	curr_lineno++;
	BEGIN(INITIAL);
	lines_holder.push_back(yytext);
	std::string s = "";
	for(size_t i = 0; i < lines_holder.size(); ++i) {
	  s += lines_holder[i];
	}
	lines_holder.clear();

	if(!string_contains_null(yytext, yyleng)) {
	    return handle_string(s);
	} else {
	    cool_yylval.error_msg = "String contains null character";
	    return ERROR;
	}
}

{STARTING_LINE} {
	curr_lineno++;
	if(num_of_ending_backslashes(yytext, strlen(yytext)) % 2 != 0) {
	    if(!string_contains_null(yytext, yyleng)) {
	      std::string s(yytext);
	      if(s[s.length() - 2] == '\\' && s[s.length() - 1] == '\n') {
		s.erase(s.length() - 2, 1);
	      }
		lines_holder.push_back(s);
		BEGIN(LINE_BREAKING);
	    } else {
		cool_yylval.error_msg = "String contains null character";
		return ERROR;
	    }
	} else {
	    cool_yylval.error_msg = "Unterminated string constant";
	    return ERROR;
	}
}

<LINE_BREAKING>{STARTING_LINE_SECOND_TYPE} {
    curr_lineno++;
    lines_holder.push_back(yytext);
}

<LINE_BREAKING>{UNQUOTED_STRING} {
    curr_lineno++;
    cool_yylval.error_msg = "Unterminated string constant";
    return ERROR;
}

<LINE_BREAKING><<EOF>> {
    BEGIN(INITIAL);
    cool_yylval.error_msg = "EOF in comment";
    return ERROR;
}

<LINE_BREAKING>{NEWLINE} {
    BEGIN(INITIAL);
    curr_lineno++;
}

{STRING} {
    if(!string_contains_null(yytext, yyleng)) {
	return handle_string(yytext);
    } else {
	cool_yylval.error_msg = "String contains null character";
	return ERROR;
    }
}

{NEWLINE} { 
    curr_lineno++;
}

{CLASS} { return CLASS; }

{ELSE} { return ELSE; }

{FI} { return FI; }

{IF} { return IF; }

{IN} { return IN; }

{INHERITS} { return INHERITS; }

{ISVOID} { return ISVOID; }

{LET} { return LET; }

{LOOP} { return LOOP; }

{POOL} { return POOL; }

{THEN} { return THEN; }

{WHILE} { return WHILE; }

{CASE} { return CASE; }

{ESAC} { return ESAC; }

{NEW} { return NEW; }

{OF} { return OF; }

{NOT} { return NOT; }

{TYPEID} {
    cool_yylval.symbol = idtable.add_string(yytext);
    return TYPEID;
}

{FALSE} {
	cool_yylval.boolean = false;
	return BOOL_CONST;
}

{TRUE} {
       cool_yylval.boolean = true;
       return BOOL_CONST;
}

{OBJECTID} {
    cool_yylval.symbol = idtable.add_string(yytext);
    return OBJECTID;
}

{WHITESPACE} {}

{MISC} {
     return (int)*yytext;
}


. {
       cool_yylval.error_msg = yytext;
       return ERROR;
}
%%

int handle_string(std::string s) {
    string text(s), res;
    /* Removing double-quote from start and end of the string */
    assert(text[0] == '"' && text[text.size() - 1] == '"');
    text.erase(0, 1);
    text.erase(text.size() - 1, text.size());

    const char arr[] = {'n', 't', 'f', 'b'};
    vector<char> esc_chars(arr, arr + sizeof(arr) / sizeof(arr[0]));
    map<char, char> esc_charsmap;
    esc_charsmap['n'] = '\n';
    esc_charsmap['t'] = '\t';
    esc_charsmap['f'] = '\f';
    esc_charsmap['b'] = '\b';

    res = text;
    for(size_t i = 1, j = 0; i < res.size(); ++i, ++j) {
	char c = res[i];
	char prev_c = res[j];

	if(c == '\0') {
	    cool_yylval.error_msg = "String contains null character";
	    return ERROR;
	}
	if(prev_c == '\\') {
            if(find(esc_chars.begin(), esc_chars.end(), c) != esc_chars.end()){
	      res.replace(j, 2, std::string(1,esc_charsmap[c]));
	    } else {
	      res.replace(j, 2, std::string(1, c));
	    }
	} 
    }

    if(res.size() > 1024) {
	cool_yylval.error_msg = "String constant too long";
        return ERROR;
    }

    cool_yylval.symbol = stringtable.add_string(const_cast<char*>(res.c_str()));
    return STR_CONST;
					  
}

size_t num_of_ending_backslashes(std::string s, size_t i) {
    size_t t = 0;
    while(i > 0) {
	  if(s[i] == '\\') t++; 
	  i--;
	}
    return t;
}

bool string_contains_null(std::string s, size_t yyleng) {
    if(s.size() == yyleng) return false;
    return true;
}
