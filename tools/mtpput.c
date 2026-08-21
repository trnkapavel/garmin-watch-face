#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <libmtp.h>

int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "usage: mtpput <local> <name> <parent_id>\n"); return 2; }
    LIBMTP_Init();
    LIBMTP_mtpdevice_t *dev = LIBMTP_Get_First_Device();
    if (!dev) { fprintf(stderr, "ZADNE ZARIZENI\n"); return 1; }

    LIBMTP_devicestorage_t *st;
    for (st = dev->storage; st != NULL; st = st->next)
        printf("storage id=%u desc=%s free=%llu\n", st->id,
               st->StorageDescription ? st->StorageDescription : "?",
               (unsigned long long)st->FreeSpaceInBytes);

    if (!dev->storage) { fprintf(stderr, "ZADNY STORAGE\n"); return 1; }

    struct stat sb;
    if (stat(argv[1], &sb) != 0) { perror("stat"); return 1; }

    LIBMTP_file_t *f = LIBMTP_new_file_t();
    f->filesize   = sb.st_size;
    f->filename   = strdup(argv[2]);
    f->filetype   = LIBMTP_FILETYPE_UNKNOWN;
    f->parent_id  = (uint32_t)strtoul(argv[3], NULL, 10);
    f->storage_id = dev->storage->id;

    printf("posilam %s -> parent=%u storage=%u (%lld B)\n",
           argv[2], f->parent_id, f->storage_id, (long long)sb.st_size);

    int ret = LIBMTP_Send_File_From_File(dev, argv[1], f, NULL, NULL);
    if (ret != 0) { fprintf(stderr, "CHYBA odeslani\n"); LIBMTP_Dump_Errorstack(dev); }
    else printf("HOTOVO item_id=%u\n", f->item_id);

    LIBMTP_destroy_file_t(f);
    LIBMTP_Release_Device(dev);
    return ret;
}
