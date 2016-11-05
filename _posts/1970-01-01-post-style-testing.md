---
layout: post
author: jacob
title: The last fake post.
hidden: true
---

{: .alert-box-white }
Lorem ipsum dolor sit amet consectetur adipiscing elit. Nunc sapien magna, molestie at commodo ut, fringilla vel velit. Ut lectus lectus, tempor sit amet convallis in, rhoncus id libero.

![Test Photo Caption]({{ site.baseurl }}/assets/img/test-photo.png)

{: .photo-caption }
Figure 1-1: Photo caption can be done by just typing beneath the image embed.

# Header1
Some text under the Header looks like this.

## Header2
Some fun text about something

## Header2.1
Some more fun text, isn't this FUN?

*italics*
**bold**

```c
int i;
int j = 0;
for(i = 0; i < j; ++i)
{
    printf("%d\n", i);010101010101010101010101010101010101010101010101010101010101
}
```

and some `inline code` too.

> block quote?<br>
> one long block quote
> or no?

![](http://i.giphy.com/ZpV2NfvmrpF84.gif)

-JT

# Just experimenting

Check out the highlighting.

```c
char *backenders[] = {
    "Nate", "CJ",
    "Jacob", "Trent"
};
```

And now for some good 'ol term output:

```shell
~$ nmap -sV 192.168.100.0/24 > scan.txt
```

And now I'll check for max length of code output:

```c
/*
 * This program opens a .pep file containing
 * protein sequence data, then prompts the user
 * to search for a motif in the data.
 *
 * @Trent Clostio | tclostio.github.io
 */
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

int strindex(char s[], char t[])
{
    int i, j, k;

    for (i = 0; s[i] != '\0'; i++) {
        for (j = i, k = 0; t[k] != '\0' && s[j] == t[k]; j++, k++)
            ;
        if (k > 0 && t[k] == '\0')
            return i;
    }
    return -1;
}
void usage()
{
    printf("\n..........::USAGE::..........\n\n");
    printf("./find_motif [file_to_read].pep\n\n");
}
int main(int argc, char *argv[])
{
    char *filename;
    char *buffer;
    char motif[100];
    long size;
    int found = 0;

    if (argc != 2) {
        usage();
        exit(1);
    }
    filename = argv[1];
    FILE *file = fopen(filename, "rb");
    if (!file) {
        printf("ERROR: File not readable.\n");
        exit(1);
    }

    fseek(file, 0L, SEEK_END);
    size = ftell(file);
    rewind(file);

    buffer = calloc(1, size + 1);
    if(!buffer) {
        fclose(file);
        fputs("MEMORY ALLOC FAILED.\n", stderr);
        exit(1);
    }
    if (1 != fread(buffer, size, 1, file)) {
        fclose(file);
        free(buffer);
        fputs("FILE READ FAILED.\n", stderr);
        exit(1);
    }

    printf("Enter motif to search:\n");
    scanf("%s", motif);
    
    while (strindex(buffer, motif) > 0) {
        found++;
        printf("Found %d occurrences.\n",
                found);
    }
    fclose(file);
    free(buffer);
    return 0;
}
```

-TC