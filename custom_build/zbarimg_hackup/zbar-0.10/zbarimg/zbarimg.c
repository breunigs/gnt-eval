#include <config.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#ifdef HAVE_UNISTD_H
# include <unistd.h>
#endif
#ifdef HAVE_SYS_TIMES_H
# include <sys/times.h>
#endif
#include <assert.h>

#include <zbar.h>
#include <wand/MagickWand.h>

/* in 6.4.5.4 MagickGetImagePixels changed to MagickExportImagePixels.
 * (still not sure this check is quite right...
 *  how does MagickGetAuthenticImagePixels fit in?)
 * ref http://bugs.gentoo.org/247292
 */
#if MagickLibVersion < 0x645
# define MagickExportImagePixels MagickGetImagePixels
#endif

static const char *note_usage =
    "usage: zbarimg [options] <image>\n"
    "\n"
    "detects bar code in sheet, orients it IN PLACE.\n"
    "Prints found barcode to STDOUT.\n"
    "\n"
    "options:\n"
    "    -h, --help      display this help text\n"
    "    --version       display version information and exit\n"
    "    -v, --verbose   increase debug output level\n"
    "    --verbose=N     set specific debug output level\n"
    "    -S<CONFIG>[=<VALUE>], --set <CONFIG>[=<VALUE>]\n"
    "                    set decoder/scanner <CONFIG> to <VALUE> (or 1)\n"
    // FIXME overlay level
    "\n"
    ;

static int exit_code = 0;
static int num_images = 0;

static zbar_processor_t *processor = NULL;

static inline int dump_error(MagickWand *wand)
{
    char *desc;
    ExceptionType severity;
    desc = MagickGetException(wand, &severity);

    if(severity >= FatalErrorException)
        exit_code = 2;
    else if(severity >= ErrorException)
        exit_code = 1;
    else
        exit_code = 0;

    static const char *sevdesc[] = { "WARNING", "ERROR", "FATAL" };
    fprintf(stderr, "%s: %s\n", sevdesc[exit_code], desc);

    MagickRelinquishMemory(desc);
    return(exit_code);
}

static int scan_image (const char *filename)
{
    if(exit_code == 3)
        return(-1);

    int found = 0;
    MagickWand *images = NewMagickWand();
    if(!MagickReadImage(images, filename) && dump_error(images))
        return(-1);

    int needsTurn = 0;
    int needsFlip = 0;

    unsigned seq, n = MagickGetNumberImages(images);

    // Find barcode
    for(seq = 0; seq < n; seq++) {
        //printf("    Detecting frame...\n");
        //fflush(stdout);
        if(!MagickSetIteratorIndex(images, seq) && dump_error(images))
            return(-1);

        zbar_image_t *zimage = zbar_image_create();
        assert(zimage);
        zbar_image_set_format(zimage, *(unsigned long*)"Y800");

        int width = MagickGetImageWidth(images);
        int height = MagickGetImageHeight(images);
        zbar_image_set_size(zimage, width, height);

        size_t bloblen = width * height;
        unsigned char *blob = malloc(bloblen);
        zbar_image_set_data(zimage, blob, bloblen, zbar_image_free_data);
        if(!MagickExportImagePixels(images, 0, 0, width, height, "I", CharPixel, blob))
            return(-1);

        zbar_process_image(processor, zimage);

        // output result data
        const zbar_symbol_t *sym = zbar_image_first_symbol(zimage);
        for(; sym; sym = zbar_symbol_next(sym)) {
            zbar_symbol_type_t typ = zbar_symbol_get_type(sym);
            if(typ == ZBAR_PARTIAL)
                continue;

            int x = zbar_symbol_get_loc_x(sym, 1);
            int y = zbar_symbol_get_loc_y(sym, 1);

            if (x > width || y > height || x < 0 || y < 0) {
                continue;
            }

            //printf("%u ", seq);
            //printf("%ux", x);
            //printf("%u ", y);
            printf("%s\n", zbar_symbol_get_data(sym));

            needsTurn = (((float) y/height) > 0.5);
            needsFlip = (seq > 0);
            found++;

            // For MathPhys Eval we only need one barcode, so skip the
            // others
            break;
        }

        fflush(stdout);

        zbar_image_destroy(zimage);

        // For MathPhys Eval we only need one barcode, so skip the others
        if(found > 0)
            break;
    }

    if(found == 0) {
        printf("No barcodes found\n");
        exit_code = 1;
        return -1;
    }

    // Turn the image if required
    if(needsTurn) {
        //printf("    Rotating...\n");
        //fflush(stdout);
        for(seq = 0; seq < n; seq++) {
            if(!MagickSetIteratorIndex(images, seq) && dump_error(images))
                return(-1);

            PixelWand *p_wand = NewPixelWand();
            PixelSetColor(p_wand, "white");

            MagickRotateImage(images, p_wand, 180);
        }
    }

    if(needsFlip) {
        //printf("    Flipping...\n");
        //fflush(stdout);
        // duplicate frames
        MagickAddImage(images, images);
        // removing first and last frame gives us the flipped image. This
        // is ugly but for some reason MagickAddImage copies the whole
        // image rather than a single frame making real flipping hard to
        // implement.
        MagickSetFirstIterator(images);
        MagickRemoveImage(images);
        MagickSetLastIterator(images);
        MagickRemoveImage(images);
    }

    if(needsTurn || needsFlip) {
        //printf("   Saving...");
        //fflush(stdout);
        if(!MagickWriteImages(images, NULL, 1) && dump_error(images))
          return(-1);
    }

    DestroyMagickWand(images);
    return(0);
}

int usage (int rc,
           const char *msg,
           const char *arg)
{
    FILE *out = (rc) ? stderr : stdout;
    if(msg) {
        fprintf(out, "%s", msg);
        if(arg)
            fprintf(out, "%s", arg);
        fprintf(out, "\n\n");
    }
    fprintf(out, "%s", note_usage);
    return(rc);
}

static inline int parse_config (const char *cfgstr, const char *arg)
{
    if(!cfgstr || !cfgstr[0])
        return(usage(1, "ERROR: need argument for option: ", arg));

    if(zbar_processor_parse_config(processor, cfgstr))
        return(usage(1, "ERROR: invalid configuration setting: ", cfgstr));

    return(0);
}

int main (int argc, const char *argv[])
{
    // option pre-scan
    int i, j;
    for(i = 1; i < argc; i++) {
        const char *arg = argv[i];
        if(arg[0] != '-')
            // first pass, skip images
            num_images++;
        else if(arg[1] != '-')
            for(j = 1; arg[j]; j++) {
                if(arg[j] == 'S') {
                    if(!arg[++j] && ++i >= argc)
                        /* FIXME parse check */
                        return(parse_config("", "-S"));
                    break;
                }
                switch(arg[j]) {
                case 'h': return(usage(0, NULL, NULL));
                case 'v': zbar_increase_verbosity(); break;
                default:
                    return(usage(1, "ERROR: unknown bundled option: -",
                                 arg + j));
                }
            }
        else if(!strcmp(arg, "--help"))
            return(usage(0, NULL, NULL));
        else if(!strcmp(arg, "--version")) {
            printf("ZBar: %s\n", PACKAGE_VERSION);
            printf("Version: %s\n",GetMagickVersion((size_t *) NULL));
            return(0);
        }
        else if(!strcmp(arg, "--verbose"))
            zbar_increase_verbosity();
        else if(!strncmp(arg, "--verbose=", 10))
            zbar_set_verbosity(strtol(argv[i] + 10, NULL, 0));
        else if(!strcmp(arg, "--set") ||
                !strncmp(arg, "--set=", 6))
            continue;
        else if(!strcmp(arg, "--")) {
            num_images += argc - i - 1;
            break;
        }
        else
            return(usage(1, "ERROR: unknown option: ", arg));
    }

    if(!num_images)
        return(usage(1, "ERROR: specify image file(s) to scan", NULL));
    num_images = 0;

    MagickWandGenesis();

    processor = zbar_processor_create(0);
    assert(processor);
    if(zbar_processor_init(processor, NULL, 0)) {
        zbar_processor_error_spew(processor, 0);
        return(1);
    }

    for(i = 1; i < argc; i++) {
        const char *arg = argv[i];
        if(!arg)
            continue;

        if(arg[0] != '-') {
            return scan_image(arg);
        }
        else if(arg[1] != '-') {
            for(j = 1; arg[j]; j++) {
                if(arg[j] == 'S') {
                    if((arg[++j])
                       ? parse_config(arg + j, "-S")
                       : parse_config(argv[++i], "-S"))
                        return(1);
                    break;
                }
            }
        }
        else if(!strcmp(arg, "--set")) {
            if(parse_config(argv[++i], "--set"))
                return(1);
        }
        else if(!strncmp(arg, "--set=", 6)) {
            if(parse_config(arg + 6, "--set="))
                return(1);
        }
        else if(!strcmp(arg, "--"))
            break;
    }

    zbar_processor_destroy(processor);
    MagickWandTerminus();
    return(0);
}
