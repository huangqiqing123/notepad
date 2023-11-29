/*
 * 02/05/2012
 *
 * JavaScriptTokenMaker.java - Parses a document into JavaScript tokens.
 * 
 * This library is distributed under a modified BSD license.  See the included
 * LICENSE file for details.
 */
package org.fife.ui.rsyntaxtextarea.modes;

import java.io.*;
import javax.swing.text.Segment;
import java.util.Stack;

import org.fife.ui.rsyntaxtextarea.*;


/**
 * Scanner for JavaScript files.  Its states could be simplified, but are
 * kept the way they are to keep a degree of similarity (i.e. copy/paste)
 * between it and HTML/JSP/PHPTokenMaker.  This should cause no difference in
 * performance.<p>
 *
 * This implementation was created using
 * <a href="https://www.jflex.de/">JFlex</a> 1.4.1; however, the generated file
 * was modified for performance.  Memory allocation needs to be almost
 * completely removed to be competitive with the handwritten lexers (subclasses
 * of <code>AbstractTokenMaker</code>), so this class has been modified so that
 * Strings are never allocated (via yytext()), and the scanner never has to
 * worry about refilling its buffer (needlessly copying chars around).
 * We can achieve this because RText always scans exactly 1 line of tokens at a
 * time, and hands the scanner this line as an array of characters (a Segment
 * really).  Since tokens contain pointers to char arrays instead of Strings
 * holding their contents, there is no need for allocating new memory for
 * Strings.<p>
 *
 * The actual algorithm generated for scanning has, of course, not been
 * modified.<p>
 *
 * If you wish to regenerate this file yourself, keep in mind the following:
 * <ul>
 *   <li>The generated <code>JavaScriptTokenMaker.java</code> file will contain two
 *       definitions of both <code>zzRefill</code> and <code>yyreset</code>.
 *       You should hand-delete the second of each definition (the ones
 *       generated by the lexer), as these generated methods modify the input
 *       buffer, which we'll never have to do.</li>
 *   <li>You should also change the declaration/definition of zzBuffer to NOT
 *       be initialized.  This is a needless memory allocation for us since we
 *       will be pointing the array somewhere else anyway.</li>
 *   <li>You should NOT call <code>yylex()</code> on the generated scanner
 *       directly; rather, you should use <code>getTokenList</code> as you would
 *       with any other <code>TokenMaker</code> instance.</li>
 * </ul>
 *
 * @author Robert Futrell
 * @version 0.9
 */
%%

%public
%class JavaScriptTokenMaker
%extends AbstractJFlexCTokenMaker
%unicode
%type org.fife.ui.rsyntaxtextarea.Token


%{

	/**
     * Token type specifying we're in a JavaScript multiline comment.
     */
    static final int INTERNAL_IN_JS_MLC				= -8;

    /**
     * Token type specifying we're in a JavaScript documentation comment.
     */
    static final int INTERNAL_IN_JS_COMMENT_DOCUMENTATION = -9;

    /**
     * Token type specifying we're in an invalid multi-line JS string.
     */
    static final int INTERNAL_IN_JS_STRING_INVALID	= -10;

    /**
     * Token type specifying we're in a valid multi-line JS string.
     */
    static final int INTERNAL_IN_JS_STRING_VALID		= -11;

    /**
     * Token type specifying we're in an invalid multi-line JS single-quoted string.
     */
    static final int INTERNAL_IN_JS_CHAR_INVALID	= -12;

    /**
     * Token type specifying we're in a valid multi-line JS single-quoted string.
     */
    static final int INTERNAL_IN_JS_CHAR_VALID		= -13;

    static final int INTERNAL_E4X = -14;

    static final int INTERNAL_E4X_INTAG = -15;

    static final int INTERNAL_E4X_MARKUP_PROCESSING_INSTRUCTION = -16;

    static final int INTERNAL_E4X_COMMENT = -17;

    static final int INTERNAL_E4X_DTD = -18;

    static final int INTERNAL_E4X_DTD_INTERNAL = -19;

    static final int INTERNAL_E4X_ATTR_SINGLE = -20;

    static final int INTERNAL_E4X_ATTR_DOUBLE = -21;

    static final int INTERNAL_E4X_MARKUP_CDATA = -22;

    /**
     * Token type specifying we're in a valid multi-line template literal.
     */
    static final int INTERNAL_IN_JS_TEMPLATE_LITERAL_VALID = -23;

    /**
     * Token type specifying we're in an invalid multi-line template literal.
     */
    static final int INTERNAL_IN_JS_TEMPLATE_LITERAL_INVALID = -24;

    /**
     * When in the JS_STRING state, whether the current string is valid.
     */
    private boolean validJSString;

    /**
     * Whether we're in an internal DTD.  Only valid if in an e4x DTD.
     */
    private boolean e4x_inInternalDtd;

    /**
     * The previous e4x state.  Only valid if in an e4x state.
     */
    private int e4x_prevState;

    /**
     * The version of JavaScript being highlighted.
     */
    private static String jsVersion;

    /**
     * Whether e4x is being highlighted.
     */
    private static boolean e4xSupported;

    /**
     * Language state set on JS tokens.  Must be 0.
     */
    private static final int LANG_INDEX_DEFAULT	= 0;

    /**
     * Language state set on E4X tokens.
     */
    private static final int LANG_INDEX_E4X = 1;

    private Stack<Boolean> varDepths;

    /**
     * Constructor.  This must be here because JFlex does not generate a
     * no-parameter constructor.
     */
    public JavaScriptTokenMaker() {
        super();
    }


    static {
        jsVersion = "1.7"; // Many folks using JS tend to be bleeding edge
        e4xSupported = true;
    }


    /**
     * Adds the token specified to the current linked list of tokens as an
     * "end token;" that is, at <code>zzMarkedPos</code>.
     *
     * @param tokenType The token's type.
     */
    private void addEndToken(int tokenType) {
        addToken(zzMarkedPos,zzMarkedPos, tokenType);
    }


    /**
     * Adds the token specified to the current linked list of tokens.
     *
     * @param tokenType The token's type.
     * @see #addToken(int, int, int)
     */
    private void addHyperlinkToken(int start, int end, int tokenType) {
        int so = start + offsetShift;
        addToken(zzBuffer, start,end, tokenType, so, true);
    }


    /**
     * Adds the token specified to the current linked list of tokens.
     *
     * @param tokenType The token's type.
     */
    private void addToken(int tokenType) {
        addToken(zzStartRead, zzMarkedPos-1, tokenType);
    }


    /**
     * Adds the token specified to the current linked list of tokens.
     *
     * @param tokenType The token's type.
     */
    private void addToken(int start, int end, int tokenType) {
        int so = start + offsetShift;
        addToken(zzBuffer, start,end, tokenType, so);
    }


    /**
     * Adds the token specified to the current linked list of tokens.
     *
     * @param array The character array.
     * @param start The starting offset in the array.
     * @param end The ending offset in the array.
     * @param tokenType The token's type.
     * @param startOffset The offset in the document at which this token
     *                    occurs.
     */
    @Override
    public void addToken(char[] array, int start, int end, int tokenType, int startOffset) {
        super.addToken(array, start,end, tokenType, startOffset);
        zzStartRead = zzMarkedPos;
    }


    /**
     * Returns the closest {@link TokenTypes} "standard" token type for a given
     * "internal" token type (e.g. one whose value is <code>&lt; 0</code>).
     */
     @Override
    public int getClosestStandardTokenTypeForInternalType(int type) {
        switch (type) {
            case INTERNAL_IN_JS_MLC:
                return TokenTypes.COMMENT_MULTILINE;
            case INTERNAL_IN_JS_COMMENT_DOCUMENTATION:
                return TokenTypes.COMMENT_DOCUMENTATION;
            case INTERNAL_IN_JS_STRING_INVALID:
            case INTERNAL_IN_JS_STRING_VALID:
            case INTERNAL_IN_JS_CHAR_INVALID:
            case INTERNAL_IN_JS_CHAR_VALID:
                return TokenTypes.LITERAL_STRING_DOUBLE_QUOTE;
            case INTERNAL_IN_JS_TEMPLATE_LITERAL_VALID:
                return TokenTypes.LITERAL_BACKQUOTE;
            case INTERNAL_IN_JS_TEMPLATE_LITERAL_INVALID:
                return TokenTypes.ERROR_STRING_DOUBLE;
        }
        return type;
    }


    /**
     * Returns the JavaScript version being highlighted.
     *
     * @return Supported JavaScript version.
     * @see #isJavaScriptCompatible(String)
     */
    public static String getJavaScriptVersion() {
        return jsVersion;
    }


    @Override
    public String[] getLineCommentStartAndEnd(int languageIndex) {
        return new String[] { "//", null };
    }


    /**
     * Returns the first token in the linked list of tokens generated
     * from <code>text</code>.  This method must be implemented by
     * subclasses so they can correctly implement syntax highlighting.
     *
     * @param text The text from which to get tokens.
     * @param initialTokenType The token type we should start with.
     * @param startOffset The offset into the document at which
     *        <code>text</code> starts.
     * @return The first <code>Token</code> in a linked list representing
     *         the syntax highlighted text.
     */
    @Override
    public Token getTokenList(Segment text, int initialTokenType, int startOffset) {

        resetTokenList();
        this.offsetShift = -text.offset + startOffset;
        validJSString = true;
        e4x_prevState = YYINITIAL;
        e4x_inInternalDtd = false;
        int languageIndex = LANG_INDEX_DEFAULT;

        // Start off in the proper state.
        int state;
        switch (initialTokenType) {
            case INTERNAL_IN_JS_MLC:
                state = JS_MLC;
                break;
            case INTERNAL_IN_JS_COMMENT_DOCUMENTATION:
                state = JS_DOCCOMMENT;
                start = text.offset;
                break;
            case INTERNAL_IN_JS_STRING_INVALID:
                state = JS_STRING;
                validJSString = false;
                break;
            case INTERNAL_IN_JS_STRING_VALID:
                state = JS_STRING;
                break;
            case INTERNAL_IN_JS_CHAR_INVALID:
                state = JS_CHAR;
                validJSString = false;
                break;
            case INTERNAL_IN_JS_CHAR_VALID:
                state = JS_CHAR;
                break;
            case INTERNAL_E4X:
                state = E4X;
                languageIndex = LANG_INDEX_E4X;
                break;
            case INTERNAL_E4X_INTAG:
                state = E4X_INTAG;
                languageIndex = LANG_INDEX_E4X;
                break;
            case INTERNAL_E4X_MARKUP_PROCESSING_INSTRUCTION:
                state = E4X_PI;
                languageIndex = LANG_INDEX_E4X;
                break;
            case INTERNAL_E4X_DTD:
                state = E4X_DTD;
                languageIndex = LANG_INDEX_E4X;
                break;
            case INTERNAL_E4X_DTD_INTERNAL:
                state = E4X_DTD;
                e4x_inInternalDtd = true;
                languageIndex = LANG_INDEX_E4X;
                break;
            case INTERNAL_E4X_ATTR_SINGLE:
                state = E4X_INATTR_SINGLE;
                languageIndex = LANG_INDEX_E4X;
                break;
            case INTERNAL_E4X_ATTR_DOUBLE:
                state = E4X_INATTR_DOUBLE;
                languageIndex = LANG_INDEX_E4X;
                break;
            case INTERNAL_E4X_MARKUP_CDATA:
                state = E4X_CDATA;
                languageIndex = LANG_INDEX_E4X;
                break;
            case INTERNAL_IN_JS_TEMPLATE_LITERAL_VALID:
                state = JS_TEMPLATE_LITERAL;
                validJSString = true;
                break;
            case INTERNAL_IN_JS_TEMPLATE_LITERAL_INVALID:
                state = JS_TEMPLATE_LITERAL;
                validJSString = false;
                break;
            default:
                if (initialTokenType<-1024) { // INTERNAL_E4X_COMMENT - prevState
                    int main = -(-initialTokenType & 0xffffff00);
                    switch (main) {
                        default: // Should never happen
                        case INTERNAL_E4X_COMMENT:
                            state = E4X_COMMENT;
                            break;
                    }
                    e4x_prevState = -initialTokenType&0xff;
                    languageIndex = LANG_INDEX_E4X;
                }
                else { // Shouldn't happen
                    state = YYINITIAL;
                }
        }

        setLanguageIndex(languageIndex);
        start = text.offset;
        s = text;
        try {
            yyreset(zzReader);
            yybegin(state);
            return yylex();
        } catch (IOException ioe) {
            ioe.printStackTrace();
            return new TokenImpl();
        }

    }


    /**
     * Returns whether e4x is being highlighted.
     *
     * @return Whether e4x is being highlighted.
     * @see #setE4xSupported(boolean)
     */
    public static boolean isE4xSupported() {
        return e4xSupported;
    }


    /**
     * Returns whether features for a specific JS version should be honored
     * while highlighting.
     *
     * @param version JavaScript version required
     * @return Whether the JavaScript version is the same or greater than
     *         version required.
     */
    public static boolean isJavaScriptCompatible(String version) {
        return jsVersion.compareTo(version) >= 0;
    }


    /**
     * Sets whether e4x should be highlighted.  A repaint should be forced on
     * all <code>RSyntaxTextArea</code>s editing JavaScript if this property
     * is changed to see the difference.
     *
     * @param supported Whether e4x should be highlighted.
     * @see #isE4xSupported()
     */
    public static void setE4xSupported(boolean supported) {
        e4xSupported = supported;
    }


    /**
     * Set the supported JavaScript version because some keywords were
     * introduced on or after this version.
     *
     * @param javaScriptVersion The version of JavaScript to support, such as
     *        "<code>1.5</code>" or "<code>1.6</code>".
     * @see #isJavaScriptCompatible(String)
     * @see #getJavaScriptVersion()
     */
    public static void setJavaScriptVersion(String javaScriptVersion) {
        jsVersion = javaScriptVersion;
    }


    /**
     * Refills the input buffer.
     *
     * @return      <code>true</code> if EOF was reached, otherwise
     *              <code>false</code>.
     */
    private boolean zzRefill() {
        return zzCurrentPos>=s.offset+s.count;
    }


    /**
     * Resets the scanner to read from a new input stream.
     * Does not close the old reader.
     *
     * All internal variables are reset, the old input stream
     * <b>cannot</b> be reused (internal buffer is discarded and lost).
     * Lexical state is set to <tt>YY_INITIAL</tt>.
     *
     * @param reader   the new input stream
     */
    public final void yyreset(java.io.Reader reader) {
        // 's' has been updated.
        zzBuffer = s.array;
        /*
         * We replaced the line below with the two below it because zzRefill
         * no longer "refills" the buffer (since the way we do it, it's always
         * "full" the first time through, since it points to the segment's
         * array).  So, we assign zzEndRead here.
         */
        //zzStartRead = zzEndRead = s.offset;
        zzStartRead = s.offset;
        zzEndRead = zzStartRead + s.count - 1;
        zzCurrentPos = zzMarkedPos = zzPushbackPos = s.offset;
        zzLexicalState = YYINITIAL;
        zzReader = reader;
        zzAtBOL  = true;
        zzAtEOF  = false;
    }


%}

Whitespace			= ([ \t\f]+)
LineTerminator			= ([\n])

Letter							= [A-Za-z]
NonzeroDigit						= [1-9]
Digit							= ("0"|{NonzeroDigit})
HexDigit							= ({Digit}|[A-Fa-f])
OctalDigit						= ([0-7])
LetterOrDigit					= ({Letter}|{Digit})
EscapedSourceCharacter				= ("u"{HexDigit}{HexDigit}{HexDigit}{HexDigit})
NonSeparator						= ([^\t\f\r\n\ \(\)\{\}\[\]\;\,\.\=\>\<\!\~\?\:\+\-\*\/\&\|\^\%\"\'\`]|"#"|"\\")
IdentifierStart					= ({Letter}|"_"|"$")
IdentifierPart						= ({IdentifierStart}|{Digit}|("\\"{EscapedSourceCharacter}))
JS_MLCBegin				= "/*"
JS_DocCommentBegin			= "/**"
JS_MLCEnd					= "*/"
JS_LineCommentBegin			= "//"
JS_IntegerHelper1			= (({NonzeroDigit}{Digit}*)|"0")
JS_IntegerHelper2			= ("0"(([xX]{HexDigit}+)|({OctalDigit}*)))
JS_IntegerLiteral			= ({JS_IntegerHelper1}[lL]?)
JS_HexLiteral				= ({JS_IntegerHelper2}[lL]?)
JS_FloatHelper1			= ([fFdD]?)
JS_FloatHelper2			= ([eE][+-]?{Digit}+{JS_FloatHelper1})
JS_FloatLiteral1			= ({Digit}+"."({JS_FloatHelper1}|{JS_FloatHelper2}|{Digit}+({JS_FloatHelper1}|{JS_FloatHelper2})))
JS_FloatLiteral2			= ("."{Digit}+({JS_FloatHelper1}|{JS_FloatHelper2}))
JS_FloatLiteral3			= ({Digit}+{JS_FloatHelper2})
JS_FloatLiteral			= ({JS_FloatLiteral1}|{JS_FloatLiteral2}|{JS_FloatLiteral3}|({Digit}+[fFdD]))
JS_ErrorNumberFormat		= (({JS_IntegerLiteral}|{JS_HexLiteral}|{JS_FloatLiteral}){NonSeparator}+)
JS_Separator				= ([\(\)\{\}\[\]\]])
JS_Separator2				= ([\;,.])
JS_NonAssignmentOperator		= ("+"|"-"|"<="|"^"|"++"|"<"|"*"|">="|"%"|"--"|">"|"/"|"!="|"?"|">>"|"!"|"&"|"=="|":"|">>"|"~"|"||"|"&&"|">>>")
JS_AssignmentOperator		= ("="|"-="|"*="|"/="|"|="|"&="|"^="|"+="|"%="|"<<="|">>="|">>>=")
JS_Operator				= ({JS_NonAssignmentOperator}|{JS_AssignmentOperator})
JS_Identifier				= ({IdentifierStart}{IdentifierPart}*)
JS_ErrorIdentifier			= ({NonSeparator}+)
JS_Regex					= ("/"([^\*\\/]|\\.)([^/\\]|\\.)*"/"[gim]*)
JS_E4xAttribute				= ("@"{Letter}{LetterOrDigit}*)

JS_BlockTag					= ("abstract"|"access"|"alias"|"augments"|"author"|"borrows"|
								"callback"|"classdesc"|"constant"|"constructor"|"constructs"|
								"copyright"|"default"|"deprecated"|"desc"|"enum"|"event"|
								"example"|"exports"|"external"|"file"|"fires"|"global"|
								"ignore"|"inner"|"instance"|"kind"|"lends"|"license"|
								"link"|"member"|"memberof"|"method"|"mixes"|"mixin"|"module"|
								"name"|"namespace"|"param"|"private"|"property"|"protected"|
								"public"|"readonly"|"requires"|"return"|"returns"|"see"|"since"|
								"static"|"summary"|"this"|"throws"|"todo"|
								"type"|"typedef"|"variation"|"version")
JS_InlineTag				= ("link"|"linkplain"|"linkcode"|"tutorial")
JS_TemplateLiteralExprStart	= ("${")

e4x_NameStartChar		= ([\:A-Z_a-z])
e4x_NameChar			= ({e4x_NameStartChar}|[\-\.0-9])
e4x_TagName				= ({e4x_NameStartChar}{e4x_NameChar}*)
e4x_Identifier			= ([^ \t\n<&;]+)
e4x_EndXml				= ([;])
e4x_EntityReference			= ([&][^; \t]*[;]?)
e4x_InTagIdentifier		= ([^ \t\n\"\'=\/>]+)
e4x_CDataBegin			= ("<![CDATA[")
e4x_CDataEnd			= ("]]>")

URLGenDelim				= ([:\/\?#\[\]@])
URLSubDelim				= ([\!\$&'\(\)\*\+,;=])
URLUnreserved			= ({LetterOrDigit}|"_"|[\-\.\~])
URLCharacter			= ({URLGenDelim}|{URLSubDelim}|{URLUnreserved}|[%])
URLCharacters			= ({URLCharacter}*)
URLEndCharacter			= ([\/\$]|{LetterOrDigit})
URL						= (((https?|f(tp|ile))"://"|"www.")({URLCharacters}{URLEndCharacter})?)


%state JS_STRING
%state JS_CHAR
%state JS_MLC
%state JS_DOCCOMMENT
%state JS_EOL_COMMENT
%state E4X
%state E4X_COMMENT
%state E4X_PI
%state E4X_DTD
%state E4X_INTAG
%state E4X_INATTR_DOUBLE
%state E4X_INATTR_SINGLE
%state E4X_CDATA
%state JS_TEMPLATE_LITERAL
%state JS_TEMPLATE_LITERAL_EXPR

%%

<YYINITIAL> {

	// Keywords
	"async" |
	"await" |
	"break" |
	"case" |
	"catch"	|
	"class"	|
	"const"	|
	"continue" |
	"debugger" |
	"delete" |
	"do" |
	"else" |
	"export" |
	"extends" |
	"finally" |
	"for" |
	"function" |
	"if" |
	"import" |
	"in" |
	"instanceof" |
	"new" |
	"null" |
	"of" |
	"static" |
	"super" |
	"switch" |
	"this" |
	"throw" |
	"try" |
	"typeof" |
	"var" |
	"void" |
	"while" |
	"with" |
    "yield"                     { addToken(Token.RESERVED_WORD); }
	"return"					{ addToken(Token.RESERVED_WORD_2); }
	
	//e4X
	"each" 						{if(e4xSupported){ addToken(Token.RESERVED_WORD);} else {addToken(Token.IDENTIFIER);} }
	//JavaScript 1.7
	"let" 						{if(isJavaScriptCompatible("1.7")){ addToken(Token.RESERVED_WORD);} else {addToken(Token.IDENTIFIER);} }
	// e4x miscellaneous
	{JS_E4xAttribute}			{ addToken(isE4xSupported() ? Token.MARKUP_TAG_ATTRIBUTE : Token.ERROR_IDENTIFIER); }
	
	// Reserved (but not yet used) ECMA keywords.
	"abstract"					{ addToken(Token.RESERVED_WORD); }
	"boolean"						{ addToken(Token.DATA_TYPE); }
	"byte"						{ addToken(Token.DATA_TYPE); }
	"char"						{ addToken(Token.DATA_TYPE); }
	"default"						{ addToken(Token.RESERVED_WORD); }
	"double"						{ addToken(Token.DATA_TYPE); }
	"enum"						{ addToken(Token.RESERVED_WORD); }
	"final"						{ addToken(Token.RESERVED_WORD); }
	"float"						{ addToken(Token.DATA_TYPE); }
	"goto"						{ addToken(Token.RESERVED_WORD); }
	"implements"					{ addToken(Token.RESERVED_WORD); }
	"int"						{ addToken(Token.DATA_TYPE); }
	"interface"					{ addToken(Token.RESERVED_WORD); }
	"long"						{ addToken(Token.DATA_TYPE); }
	"native"						{ addToken(Token.RESERVED_WORD); }
	"package"						{ addToken(Token.RESERVED_WORD); }
	"private"						{ addToken(Token.RESERVED_WORD); }
	"protected"					{ addToken(Token.RESERVED_WORD); }
	"public"						{ addToken(Token.RESERVED_WORD); }
	"short"						{ addToken(Token.DATA_TYPE); }
	"synchronized"					{ addToken(Token.RESERVED_WORD); }
	"throws"						{ addToken(Token.RESERVED_WORD); }
	"transient"					{ addToken(Token.RESERVED_WORD); }
	"volatile"					{ addToken(Token.RESERVED_WORD); }

	// Literals.
	"false" |
	"true"						{ addToken(Token.LITERAL_BOOLEAN); }
	"NaN"						{ addToken(Token.RESERVED_WORD); }
	"Infinity"					{ addToken(Token.RESERVED_WORD); }

	// Functions.
	"eval" |
	"parseInt" |
	"parseFloat" |
	"escape" |
	"unescape" |
	"isNaN" |
	"isFinite"						{ addToken(Token.FUNCTION); }

	{LineTerminator}				{ addNullToken(); return firstToken; }
	{JS_Identifier}					{ addToken(Token.IDENTIFIER); }
	{Whitespace}					{ addToken(Token.WHITESPACE); }

	/* String/Character literals. */
	[\']							{ start = zzMarkedPos-1; validJSString = true; yybegin(JS_CHAR); }
	[\"]							{ start = zzMarkedPos-1; validJSString = true; yybegin(JS_STRING); }
	[\`]							{ start = zzMarkedPos-1; validJSString = true; yybegin(JS_TEMPLATE_LITERAL); }

	/* Comment literals. */
	"/**/"							{ addToken(Token.COMMENT_MULTILINE); }
	{JS_MLCBegin}					{ start = zzMarkedPos-2; yybegin(JS_MLC); }
	{JS_DocCommentBegin}			{ start = zzMarkedPos-3; yybegin(JS_DOCCOMMENT); }
	{JS_LineCommentBegin}			{ start = zzMarkedPos-2; yybegin(JS_EOL_COMMENT); }

	/* Attempt to identify regular expressions (not foolproof) - do after comments! */
	{JS_Regex}						{
										boolean highlightedAsRegex = false;
										if (firstToken==null) {
											addToken(Token.REGEX);
											highlightedAsRegex = true;
										}
										else {
											// If this is *likely* to be a regex, based on
											// the previous token, highlight it as such.
											Token t = firstToken.getLastNonCommentNonWhitespaceToken();
											if (RSyntaxUtilities.regexCanFollowInJavaScript(t)) {
												addToken(Token.REGEX);
												highlightedAsRegex = true;
											}
										}
										// If it doesn't *appear* to be a regex, highlight it as
										// individual tokens.
										if (!highlightedAsRegex) {
											int temp = zzStartRead + 1;
											addToken(zzStartRead, zzStartRead, Token.OPERATOR);
											zzStartRead = zzCurrentPos = zzMarkedPos = temp;
										}
									}

	/* Separators. */
	{JS_Separator}					{ addToken(Token.SEPARATOR); }
	{JS_Separator2}					{ addToken(Token.IDENTIFIER); }

	/* Operators. */
	[\+]?"="{Whitespace}*"<"		{
										int start = zzStartRead;
										int operatorLen = yycharat(0)=='+' ? 2 : 1;
										int yylen = yylength(); // Cache before first addToken() invalidates it
										//System.out.println("'" + yytext() + "': " + yylength() + ", " + (operatorLen+1));
										addToken(zzStartRead,zzStartRead+operatorLen-1, Token.OPERATOR);
										if (yylen>operatorLen+1) {
											//System.out.println((start+operatorLen) + ", " + (zzMarkedPos-2));
											addToken(start+operatorLen,zzMarkedPos-2, Token.WHITESPACE);
										}
										zzStartRead = zzCurrentPos = zzMarkedPos = zzMarkedPos - 1;
										if (isE4xSupported()) {
											// Scanning will continue with "<" as markup tag start
											yybegin(E4X, LANG_INDEX_E4X);
										}
										// Found e4x (or syntax error) but option not enabled;
										// Scanning will continue at "<" as operator
									}
	{JS_Operator}					{ addToken(Token.OPERATOR); }

	/* Numbers */
	{JS_IntegerLiteral}				{ addToken(Token.LITERAL_NUMBER_DECIMAL_INT); }
	{JS_HexLiteral}				{ addToken(Token.LITERAL_NUMBER_HEXADECIMAL); }
	{JS_FloatLiteral}				{ addToken(Token.LITERAL_NUMBER_FLOAT); }
	{JS_ErrorNumberFormat}			{ addToken(Token.ERROR_NUMBER_FORMAT); }

	{JS_ErrorIdentifier}			{ addToken(Token.ERROR_IDENTIFIER); }

	/* Ended with a line not in a string or comment. */
	<<EOF>>						{ addNullToken(); return firstToken; }

	/* Catch any other (unhandled) characters and flag them as bad. */
	.							{ addToken(Token.ERROR_IDENTIFIER); }

}

<JS_STRING> {
	[^\n\\\"]+				{}
	\\x{HexDigit}{2}		{}
	\\x						{ /* Invalid latin-1 character \xXX */ validJSString = false; }
	\\u{HexDigit}{4}		{}
	\\u						{ /* Invalid Unicode character \\uXXXX */ validJSString = false; }
	\\.						{ /* Skip all escaped chars. */ }
	\\						{ /* Line ending in '\' => continue to next line. */
								if (validJSString) {
									addToken(start,zzStartRead, Token.LITERAL_STRING_DOUBLE_QUOTE);
									addEndToken(INTERNAL_IN_JS_STRING_VALID);
								}
								else {
									addToken(start,zzStartRead, Token.ERROR_STRING_DOUBLE);
									addEndToken(INTERNAL_IN_JS_STRING_INVALID);
								}
								return firstToken;
							}
	\"						{ int type = validJSString ? Token.LITERAL_STRING_DOUBLE_QUOTE : Token.ERROR_STRING_DOUBLE; addToken(start,zzStartRead, type); yybegin(YYINITIAL); }
	\n |
	<<EOF>>					{ addToken(start,zzStartRead-1, Token.ERROR_STRING_DOUBLE); addNullToken(); return firstToken; }
}

<JS_CHAR> {
	[^\n\\\']+				{}
	\\x{HexDigit}{2}		{}
	\\x						{ /* Invalid latin-1 character \xXX */ validJSString = false; }
	\\u{HexDigit}{4}		{}
	\\u						{ /* Invalid Unicode character \\uXXXX */ validJSString = false; }
	\\.						{ /* Skip all escaped chars. */ }
	\\						{ /* Line ending in '\' => continue to next line. */
								if (validJSString) {
									addToken(start,zzStartRead, Token.LITERAL_CHAR);
									addEndToken(INTERNAL_IN_JS_CHAR_VALID);
								}
								else {
									addToken(start,zzStartRead, Token.ERROR_CHAR);
									addEndToken(INTERNAL_IN_JS_CHAR_INVALID);
								}
								return firstToken;
							}
	\'						{ int type = validJSString ? Token.LITERAL_CHAR : Token.ERROR_CHAR; addToken(start,zzStartRead, type); yybegin(YYINITIAL); }
	\n |
	<<EOF>>					{ addToken(start,zzStartRead-1, Token.ERROR_CHAR); addNullToken(); return firstToken; }
}

<JS_TEMPLATE_LITERAL> {
	[^\n\\\$\`]+				{}
	\\x{HexDigit}{2}		{}
	\\x						{ /* Invalid latin-1 character \xXX */ validJSString = false; }
	\\u{HexDigit}{4}		{}
	\\u						{ /* Invalid Unicode character \\uXXXX */ validJSString = false; }
	\\.						{ /* Skip all escaped chars. */ }

	{JS_TemplateLiteralExprStart}	{
								addToken(start, zzStartRead - 1, Token.LITERAL_BACKQUOTE);
								start = zzMarkedPos-2;
								if (varDepths==null) {
									varDepths = new Stack<>();
								}
								else {
									varDepths.clear();
								}
								varDepths.push(Boolean.TRUE);
								yybegin(JS_TEMPLATE_LITERAL_EXPR);
							}
	"$"						{ /* Skip valid '$' that is not part of template literal expression start */ }
	
	\`						{ int type = validJSString ? Token.LITERAL_BACKQUOTE : Token.ERROR_STRING_DOUBLE; addToken(start,zzStartRead, type); yybegin(YYINITIAL); }

	/* Line ending in '\' => continue to next line, though not necessary in template strings. */
	\\ |
	\n |
	<<EOF>>					{
								if (validJSString) {
									addToken(start, zzStartRead - 1, Token.LITERAL_BACKQUOTE);
									addEndToken(INTERNAL_IN_JS_TEMPLATE_LITERAL_VALID);
								}
								else {
									addToken(start,zzStartRead - 1, Token.ERROR_STRING_DOUBLE);
									addEndToken(INTERNAL_IN_JS_TEMPLATE_LITERAL_INVALID);
								}
								return firstToken;
							}
}

<JS_TEMPLATE_LITERAL_EXPR> {
	[^\}\$\n]+			{}
	"}"					{
							if (!varDepths.empty()) {
								varDepths.pop();
								if (varDepths.empty()) {
									addToken(start,zzStartRead, Token.VARIABLE);
									start = zzMarkedPos;
									yybegin(JS_TEMPLATE_LITERAL);
								}
							}
						}
	{JS_TemplateLiteralExprStart} { varDepths.push(Boolean.TRUE); }
	"$"					{}
	\n |
	<<EOF>>				{
							// TODO: This isn't right.  The expression and its depth should continue to the next line.
							addToken(start,zzStartRead-1, Token.VARIABLE); addEndToken(INTERNAL_IN_JS_TEMPLATE_LITERAL_INVALID); return firstToken;
						}
}

<JS_MLC> {
	// JavaScript MLC's.  This state is essentially Java's MLC state.
	[^hwf\n\*]+			{}
	{URL}					{ int temp=zzStartRead; addToken(start,zzStartRead-1, Token.COMMENT_MULTILINE); addHyperlinkToken(temp,zzMarkedPos-1, Token.COMMENT_MULTILINE); start = zzMarkedPos; }
	[hwf]					{}
	{JS_MLCEnd}				{ yybegin(YYINITIAL); addToken(start,zzStartRead+1, Token.COMMENT_MULTILINE); }
	\*						{}
	\n |
	<<EOF>>					{ addToken(start,zzStartRead-1, Token.COMMENT_MULTILINE); addEndToken(INTERNAL_IN_JS_MLC); return firstToken; }
}

<JS_DOCCOMMENT> {
	[^hwf\@\{\n\<\*]+			{}
	{URL}						{ int temp=zzStartRead; addToken(start,zzStartRead-1, Token.COMMENT_DOCUMENTATION); addHyperlinkToken(temp,zzMarkedPos-1, Token.COMMENT_DOCUMENTATION); start = zzMarkedPos; }
	[hwf]						{}

	"@"{JS_BlockTag}			{ int temp=zzStartRead; addToken(start,zzStartRead-1, Token.COMMENT_DOCUMENTATION); addToken(temp,zzMarkedPos-1, Token.COMMENT_KEYWORD); start = zzMarkedPos; }
	"@"							{}
	"{@"{JS_InlineTag}[^\}]*"}"	{ int temp=zzStartRead; addToken(start,zzStartRead-1, Token.COMMENT_DOCUMENTATION); addToken(temp,zzMarkedPos-1, Token.COMMENT_KEYWORD); start = zzMarkedPos; }
	"{"							{}
	\n							{ addToken(start,zzStartRead-1, Token.COMMENT_DOCUMENTATION); addEndToken(INTERNAL_IN_JS_COMMENT_DOCUMENTATION); return firstToken; }
	"<"[/]?({Letter}[^\>]*)?">"	{ int temp=zzStartRead; addToken(start,zzStartRead-1, Token.COMMENT_DOCUMENTATION); addToken(temp,zzMarkedPos-1, Token.COMMENT_MARKUP); start = zzMarkedPos; }
	\<							{}
	{JS_MLCEnd}					{ yybegin(YYINITIAL); addToken(start,zzStartRead+1, Token.COMMENT_DOCUMENTATION); }
	\*							{}
	<<EOF>>						{ yybegin(YYINITIAL); addToken(start,zzEndRead, Token.COMMENT_DOCUMENTATION); addEndToken(INTERNAL_IN_JS_COMMENT_DOCUMENTATION); return firstToken; }
}

<JS_EOL_COMMENT> {
	[^hwf\n]+				{}
	{URL}					{ int temp=zzStartRead; addToken(start,zzStartRead-1, Token.COMMENT_EOL); addHyperlinkToken(temp,zzMarkedPos-1, Token.COMMENT_EOL); start = zzMarkedPos; }
	[hwf]					{}
	\n |
	<<EOF>>					{ addToken(start,zzStartRead-1, Token.COMMENT_EOL); addNullToken(); return firstToken; }
}

<E4X> {
	"<!--"						{ start = zzStartRead; e4x_prevState = zzLexicalState; yybegin(E4X_COMMENT); }
	{e4x_CDataBegin}			{ addToken(Token.MARKUP_CDATA_DELIMITER); start = zzMarkedPos; yybegin(E4X_CDATA); }
	"<!"						{ start = zzMarkedPos-2; e4x_inInternalDtd = false; yybegin(E4X_DTD); }
	"<?"						{ start = zzMarkedPos-2; yybegin(E4X_PI); }
	"<"{e4x_TagName}			{
									int count = yylength();
									addToken(zzStartRead,zzStartRead, Token.MARKUP_TAG_DELIMITER);
									addToken(zzMarkedPos-(count-1), zzMarkedPos-1, Token.MARKUP_TAG_NAME);
									yybegin(E4X_INTAG);
								}
	"</"{e4x_TagName}			{
									int count = yylength();
									addToken(zzStartRead,zzStartRead+1, Token.MARKUP_TAG_DELIMITER);
									addToken(zzMarkedPos-(count-2), zzMarkedPos-1, Token.MARKUP_TAG_NAME);
									yybegin(E4X_INTAG);
								}
	"<"							{ addToken(Token.MARKUP_TAG_DELIMITER); yybegin(E4X_INTAG); }
	"</"						{ addToken(Token.MARKUP_TAG_DELIMITER); yybegin(E4X_INTAG); }
	{e4x_Identifier}			{ addToken(Token.IDENTIFIER); }
	{e4x_EndXml}				{ yybegin(YYINITIAL, LANG_INDEX_DEFAULT); addToken(Token.IDENTIFIER); }
	{e4x_EntityReference}				{ addToken(Token.MARKUP_ENTITY_REFERENCE); }
	{Whitespace}				{ addToken(Token.WHITESPACE); }
	{LineTerminator} |
	<<EOF>>						{ addEndToken(INTERNAL_E4X); return firstToken; }
}

<E4X_COMMENT> {
	[^hwf\n\-]+					{}
	{URL}						{ int temp=zzStartRead; addToken(start,zzStartRead-1, Token.MARKUP_COMMENT); addHyperlinkToken(temp,zzMarkedPos-1, Token.MARKUP_COMMENT); start = zzMarkedPos; }
	[hwf]						{}
	"-->"						{ int temp = zzMarkedPos; addToken(start,zzStartRead+2, Token.MARKUP_COMMENT); start = temp; yybegin(e4x_prevState); }
	"-"							{}
	{LineTerminator} |
	<<EOF>>						{ addToken(start,zzStartRead-1, Token.MARKUP_COMMENT); addEndToken(INTERNAL_E4X_COMMENT - e4x_prevState); return firstToken; }
}

<E4X_PI> {
	[^\n\?]+					{}
	"?>"						{ yybegin(E4X); addToken(start,zzStartRead+1, Token.MARKUP_PROCESSING_INSTRUCTION); }
	"?"							{}
	{LineTerminator} |
	<<EOF>>						{ addToken(start,zzStartRead-1, Token.MARKUP_PROCESSING_INSTRUCTION); addEndToken(INTERNAL_E4X_MARKUP_PROCESSING_INSTRUCTION); return firstToken; }
}

<E4X_DTD> {
	[^\n\[\]<>]+				{}
	"<!--"						{ int temp = zzStartRead; addToken(start,zzStartRead-1, Token.MARKUP_DTD); start = temp; e4x_prevState = zzLexicalState; yybegin(E4X_COMMENT); }
	"<"							{}
	"["							{ e4x_inInternalDtd = true; }
	"]"							{ e4x_inInternalDtd = false; }
	">"							{ if (!e4x_inInternalDtd) { yybegin(E4X); addToken(start,zzStartRead, Token.MARKUP_DTD); } }
	{LineTerminator} |
	<<EOF>>						{ addToken(start,zzStartRead-1, Token.MARKUP_DTD); addEndToken(e4x_inInternalDtd ? INTERNAL_E4X_DTD_INTERNAL : INTERNAL_E4X_DTD); return firstToken; }
}

<E4X_INTAG> {
	{e4x_InTagIdentifier}		{ addToken(Token.MARKUP_TAG_ATTRIBUTE); }
	{Whitespace}				{ addToken(Token.WHITESPACE); }
	"="							{ addToken(Token.OPERATOR); }
	"/"							{ addToken(Token.MARKUP_TAG_DELIMITER); /* Not valid but we'll still accept it */ }
	"/>"						{ yybegin(E4X); addToken(Token.MARKUP_TAG_DELIMITER); }
	">"							{ yybegin(E4X); addToken(Token.MARKUP_TAG_DELIMITER); }
	[\"]						{ start = zzMarkedPos-1; yybegin(E4X_INATTR_DOUBLE); }
	[\']						{ start = zzMarkedPos-1; yybegin(E4X_INATTR_SINGLE); }
	<<EOF>>						{ addToken(start,zzStartRead-1, INTERNAL_E4X_INTAG); return firstToken; }
}

<E4X_INATTR_DOUBLE> {
	[^\"]*						{}
	[\"]						{ yybegin(E4X_INTAG); addToken(start,zzStartRead, Token.MARKUP_TAG_ATTRIBUTE_VALUE); }
	<<EOF>>						{ addToken(start,zzStartRead-1, Token.MARKUP_TAG_ATTRIBUTE_VALUE); addEndToken(INTERNAL_E4X_ATTR_DOUBLE); return firstToken; }
}

<E4X_INATTR_SINGLE> {
	[^\']*						{}
	[\']						{ yybegin(E4X_INTAG); addToken(start,zzStartRead, Token.MARKUP_TAG_ATTRIBUTE_VALUE); }
	<<EOF>>						{ addToken(start,zzStartRead-1, Token.MARKUP_TAG_ATTRIBUTE_VALUE); addEndToken(INTERNAL_E4X_ATTR_SINGLE); return firstToken; }
}

<E4X_CDATA> {
	[^\]]+						{}
	{e4x_CDataEnd}				{ int temp=zzStartRead; yybegin(E4X); addToken(start,zzStartRead-1, Token.MARKUP_CDATA); addToken(temp,zzMarkedPos-1, Token.MARKUP_CDATA_DELIMITER); }
	"]"							{}
	<<EOF>>						{ addToken(start,zzStartRead-1, Token.MARKUP_CDATA); addEndToken(INTERNAL_E4X_MARKUP_CDATA); return firstToken; }
}
