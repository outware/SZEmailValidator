#import "SZEmailValidator.h"

struct SZEmailParserState {
    BOOL quoted : 1;
    BOOL escaped : 1;
    BOOL domain : 1;
    BOOL dot : 1;
    BOOL followingQuoteBlock : 1;
};

@implementation SZEmailValidator

+ (BOOL)isValid:(nonnull NSString *)candidate {
    NSParameterAssert(candidate != nil);

    unsigned int domainPartStart = 0;
    unsigned int commentDepth = 0;

    struct SZEmailParserState state;

    state.dot = NO;
    state.quoted = NO;
    state.escaped = NO;
    state.followingQuoteBlock = NO;
    state.domain = NO;

    for (unsigned int i = 0; i < candidate.length; ++i) {
        unichar character = [candidate characterAtIndex:i];

        if (!state.domain) {

            // Do not allow characters beyond the ASCII set in the username
            if (character > 126) return NO;

            // Do not allow NULL
            if (character == 0) return NO;

            // Do not allow LF
            if (character == 10) return NO;
        }

        if (i > 253) {

            // Do not allow more than 254 characters in the entire address
            return NO;
        }

        // The only characters that can follow a quote block are @ and period.
        if (state.followingQuoteBlock) {
            if (character != '@' && character != '.') {
                return NO;
            }

            state.followingQuoteBlock = NO;
        }

        switch (character) {
            case '@':

                if (state.domain) {

                    // @ not allowed in the domain portion of the address
                    return NO;

                } else if (state.quoted) {

                    // Ignore @ signs when quoted

                } else if (state.dot) {

                    // Dots are not allowed as the final character in the local
                    // part
                    return NO;

                } else {

                    // Swapping to the domain portion of the address
                    state.domain = YES;
                    domainPartStart = i + 1;

                    if (i > 64) {

                        // Do not allow more than 63 characters in the local part
                        return NO;

                    }
                }

                // No longer in dot/escape mode
                state.dot = NO;
                state.escaped = NO;

                break;

            case '(':

                // Comments only activate when not quoted or escaped
                if (!state.quoted && !state.escaped) {
                    ++commentDepth;
                }

                break;

            case ')':

                // Comments only activate when not quoted or escaped
                if (!state.quoted && !state.escaped) {

                    if (commentDepth == 0) return NO;

                    --commentDepth;
                }

                break;

            case '\\':

                if (!state.quoted && commentDepth == 0) {

                    // Backslash isn't allowed outside of quote/comment mode
                    return NO;
                }

                // Flip the escape bit to enter/exit escape mode
                state.escaped = !state.escaped;

                // No longer in dot mode
                state.dot = NO;

                break;

            case '"':

                if (state.domain && commentDepth == 0) {

                    // quote not allowed in the domain portion of the address
                    // outside of a comment
                    return NO;
                }

                if (!state.escaped) {

                    // Quotes are only allowed at the start of the local part,
                    // after a dot or to close an existing quote part
                    if (i == 0 || state.dot || state.quoted) {

                        // Remember that we just left a quote block
                        if (state.quoted) {
                            state.followingQuoteBlock = YES;
                        }

                        // Flip the quote bit to enter/exit quote mode
                        state.quoted = !state.quoted;
                    } else {
                        return NO;
                    }
                }

                // No longer in dot/escape mode
                state.dot = NO;
                state.escaped = NO;

                break;

            case '.':

                if (i == 0) {

                    // Dots are not allowed as the first character of the local
                    // part
                    return NO;

                } else if (i == domainPartStart) {

                    // Dots are not allowed as the first character of the domain
                    // part
                    return NO;

                } else if (i == candidate.length - 1) {

                    // Dots are not allowed as the last character of the domain
                    // part
                    return NO;
                }

                if (!state.quoted) {

                    if (state.dot) {

                        // Cannot allow adjacent dots
                        return NO;
                    } else {

                        // Entering dot mode
                        state.dot = YES;
                    }

                }

                // No longer in escape mode
                state.escaped = NO;

                break;

            case ' ':
            case ',':
            case '[':
            case ']':
            case 1:
            case 2:
            case 3:
            case 4:
            case 5:
            case 6:
            case 7:
            case 8:
            case 9:
            case 11:
            case 13:
            case 15:

                // These characters can only appear when quoted
                if (!state.quoted) {
                    return NO;
                }

            default:

                // No longer in dot/escape mode
                state.dot = NO;
                state.escaped = NO;

                // Do not allow characters outside of unicode, numerals, hyphens
                // and periods in the domain part.  We use letterCharacterSet
                // because we're supporting internationalised domain names.
                // We don't have to do anything special with the name; that's up
                // to the email client/server to handle.
                if (state.domain) {
                    if (![[NSCharacterSet letterCharacterSet] characterIsMember:character] &&
                        ![[NSCharacterSet decimalDigitCharacterSet] characterIsMember:character] &&
                        character != '-') {

                        return NO;
                    }
                }

                break;
        }
    }

    // Do not allow unclosed comments
    if (commentDepth > 0) return NO;

    // If we didn't identify a local and a domain part the address isn't valid
    if (!state.domain) return NO;
    if (candidate.length == domainPartStart) return NO;
    if (domainPartStart == 1) return NO;

    // Validate domain name components
    NSArray *components = [[candidate substringFromIndex:domainPartStart] componentsSeparatedByString:@"."];

    for (NSString *item in components) {

        // We can't allow a hyphen as the first or last char in a domain name
        // component
        if ([item characterAtIndex:0] == '-' || [item characterAtIndex:item.length - 1] == '-') {
            return NO;
        }

        // Items must not be longer than 63 chars
        if (item.length > 63) return NO;
    }

    return YES;
}

@end
