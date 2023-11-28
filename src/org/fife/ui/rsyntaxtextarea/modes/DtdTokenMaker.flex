/*
 * 04/12/2012
 *
 * DtdTokenMaker.java - Generates tokens for DTD syntax highlighting.
 * 
 * This library is distributed under a modified BSD license.  See the included
 * LICENSE file for details.
 */
package org.fife.ui.rsyntaxtextarea.modes;

import java.io.*;
import javax.swing.text.Segment;

import org.fife.ui.rsyntaxtextarea.*;


/**
 * Scanner for DTD files.
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
 *   <li>The generated <code>XMLTokenMaker.java</code> file will contain two
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
 * @version 1.0
 */
%%

%public
%class DtdTokenMaker
%extends AbstractJFlexTokenMaker
%unicode
%type org.fife.ui.rsyntaxtextarea.Token


%{

	/**
	 * Token type specific to XMLTokenMaker denoting a line ending with an
	 * unclosed XML tag; thus a new line is beginning still inside of the tag.
	 */
	public static final int INTERNAL_INTAG_START					= -1;

	/**
	 * Token type specific to XMLTokenMaker denoting a line ending with an
	 * unclosed DOCTYPE element.
	 */
	public static final int INTERNAL_INTAG_ELEMENT					= -2;

	/**
	 * Token type specific to XMLTokenMaker denoting a line ending with an
	 * unclosed, locally-defined DTD in a DOCTYPE element.
	 */
	public static final int INTERNAL_INTAG_ATTLIST			= -3;

	/**
	 * Token type specific to XMLTokenMaker denoting a line ending with an
	 * unclosed comment.  The state to return to when this comment ends is
	 * embedded in the token type as well.
	 */
	public static final int INTERNAL_IN_COMMENT			= -(1<<11);

	/**
	 * The state we were in prior to the current one.  This is used to know
	 * what state to resume after an MLC ends.
	 */
	private int prevState;


	/**
	 * Constructor.  This must be here because JFlex does not generate a
	 * no-parameter constructor.
	 */
	public DtdTokenMaker() {
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
	 * Always returns <tt>false</tt>, as you never want "mark occurrences"
	 * working in XML files.
	 *
	 * @param type The token type.
	 * @return Whether tokens of this type should have "mark occurrences"
	 *         enabled.
	 */
	@Override
	public boolean getMarkOccurrencesOfTokenType(int type) {
		return false;
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
	public Token getTokenList(Segment text, int initialTokenType, int startOffset) {

		resetTokenList();
		this.offsetShift = -text.offset + startOffset;
		prevState = YYINITIAL;

		// Start off in the proper state.
		int state = YYINITIAL;
		switch (initialTokenType) {
			case INTERNAL_INTAG_START:
				state = INTAG_START;
				break;
			case INTERNAL_INTAG_ELEMENT:
				state = INTAG_ELEMENT;
				break;
			case INTERNAL_INTAG_ATTLIST:
				state = INTAG_ATTLIST;
				break;
			default:
				if (initialTokenType<-1024) { // INTERNAL_IN_COMMENT - prevState
					int main = -(-initialTokenType & 0xffffff00);
					switch (main) {
						default: // Should never happen
						case INTERNAL_IN_COMMENT:
							state = COMMENT;
							break;
					}
					prevState = -initialTokenType&0xff;
				}
				else { // Shouldn't happen
					state = YYINITIAL;
				}
		}

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

Whitespace			= ([ \t\f])
LineTerminator			= ([\n])
UnclosedString		= ([\"][^\"]*)
UnclosedChar		= ([\'][^\']*)

URLGenDelim				= ([:\/\?#\[\]@])
URLSubDelim				= ([\!\$&'\(\)\*\+,;=])
URLUnreserved			= ([A-Za-z_0-9\-\.\~])
URLCharacter			= ({URLGenDelim}|{URLSubDelim}|{URLUnreserved}|[%])
URLCharacters			= ({URLCharacter}*)
URLEndCharacter			= ([\/\$A-Za-z0-9])
URL						= (((https?|f(tp|ile))"://"|"www.")({URLCharacters}{URLEndCharacter})?)

%state COMMENT
%state INTAG_START
%state INTAG_ELEMENT
%state INTAG_ATTLIST

%%

<YYINITIAL> {
	([^ \t\f<]+)				{ /* Not really valid */ addToken(Token.IDENTIFIER); }
	"<!--"						{ start = zzStartRead; prevState = zzLexicalState; yybegin(COMMENT); }
	"<!"						{ addToken(Token.MARKUP_TAG_DELIMITER); yybegin(INTAG_START); }
	"<"							{ addToken(Token.IDENTIFIER); }
	{Whitespace}+				{ addToken(Token.WHITESPACE); }
	{LineTerminator} |
	<<EOF>>						{ addNullToken(); return firstToken; }
}

<COMMENT> {
	[^hwf\n\-]+					{}
	{URL}						{ int temp=zzStartRead; addToken(start,zzStartRead-1, Token.MARKUP_COMMENT); addHyperlinkToken(temp,zzMarkedPos-1, Token.MARKUP_COMMENT); start = zzMarkedPos; }
	[hwf]						{}
	"-->"						{ int temp = zzMarkedPos; addToken(start,zzStartRead+2, Token.MARKUP_COMMENT); start = temp; yybegin(prevState); }
	"-"							{}
	{LineTerminator} |
	<<EOF>>						{ addToken(start,zzStartRead-1, Token.MARKUP_COMMENT); addEndToken(INTERNAL_IN_COMMENT - prevState); return firstToken; }
}

<INTAG_START> {
	("ELEMENT")					{ addToken(Token.MARKUP_TAG_NAME); yybegin(INTAG_ELEMENT); }
	("ATTLIST")					{ addToken(Token.MARKUP_TAG_NAME); yybegin(INTAG_ATTLIST); }
	([^ \t\f>]+)				{ addToken(Token.IDENTIFIER); }
	{Whitespace}+				{ addToken(Token.WHITESPACE); }
	(">")						{ addToken(Token.MARKUP_TAG_DELIMITER); yybegin(YYINITIAL); }
	<<EOF>>						{ addEndToken(INTERNAL_INTAG_START); return firstToken; }
}

<INTAG_ELEMENT> {
	([^ \t\f>]+)				{ addToken(Token.MARKUP_TAG_ATTRIBUTE); }
	{Whitespace}+				{ addToken(Token.WHITESPACE); }
	(">")						{ addToken(Token.MARKUP_TAG_DELIMITER); yybegin(YYINITIAL); }
	<<EOF>>						{ addEndToken(INTERNAL_INTAG_ELEMENT); return firstToken; }
}

<INTAG_ATTLIST> {
	("CDATA"|"#IMPLIED"|"#REQUIRED")	{ addToken(Token.MARKUP_PROCESSING_INSTRUCTION); }
	([^ \t\f>\"\']+)			{ addToken(Token.MARKUP_TAG_ATTRIBUTE); }
	({UnclosedString}[\"]?)		{ addToken(Token.MARKUP_TAG_ATTRIBUTE_VALUE); }
	({UnclosedChar}[\']?)		{ addToken(Token.MARKUP_TAG_ATTRIBUTE_VALUE); }
	{Whitespace}+				{ addToken(Token.WHITESPACE); }
	(">")						{ addToken(Token.MARKUP_TAG_DELIMITER); yybegin(YYINITIAL); }
	<<EOF>>						{ addEndToken(INTERNAL_INTAG_ATTLIST); return firstToken; }
}
