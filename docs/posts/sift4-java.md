---
date: 2016-12-11
authors: [nathan]
description: >
  Our new blog is built with the brand new built-in blog plugin. You can build
  a blog alongside your documentation or standalone
categories:
  - Blog
---

# Sift4 String Comparison in Java
<!-- more -->

More of a quick snippet here than a blog post, but for fans of the [sift4 string comparison algorithm](https://siderite.dev/blog/super-fast-and-accurate-string-distance.html), here's a [java implementation](https://gist.github.com/kag0/5fe7ba9f3f400c00c74698924e5fe4d0).  
Hopefully it will be available soon in the handy [java string similarity library](https://github.com/tdebatty/java-string-similarity) and on maven central. In the meantime it can be found in its entirety below, or in the original post on siderite's blog.

```java
/**
 * Sift4 - common version
 * online algorithm to compute the distance between two strings in O(n)
 * Algorithm by siderite, java port by Nathan Fischer 2016
 * https://siderite.dev/blog/super-fast-and-accurate-string-distance.html
 * @param s1
 * @param s2
 * @param maxOffset the number of characters to search for matching letters
 * @return
 */
public static double sift4(String s1, String s2, int maxOffset) {
	class Offset{
		int c1;
		int c2;
		boolean trans;

		Offset(int c1, int c2, boolean trans) {
			this.c1 = c1;
			this.c2 = c2;
			this.trans = trans;
		}
	}

	if(s1 == null || s1.isEmpty())
		return s2 == null ? 0 : s2.length();

	if(s2 == null || s2.isEmpty())
		return s1.length();

	int l1=s1.length();
	int l2=s2.length();

	int c1 = 0;  //cursor for string 1
	int c2 = 0;  //cursor for string 2
	int lcss = 0;  //largest common subsequence
	int local_cs = 0; //local common substring
	int trans = 0;  //number of transpositions ('ab' vs 'ba')
	LinkedList<Offset> offset_arr=new LinkedList<>();  //offset pair array, for computing the transpositions

	while ((c1 < l1) && (c2 < l2)) {
		if (s1.charAt(c1) == s2.charAt(c2)) {
			local_cs++;
			boolean isTrans=false;
			//see if current match is a transposition
			int i=0;
			while (i<offset_arr.size()) {
				Offset ofs=offset_arr.get(i);
				if (c1<=ofs.c1 || c2 <= ofs.c2) {
					// when two matches cross, the one considered a transposition is the one with the largest difference in offsets
					isTrans=Math.abs(c2-c1)>=Math.abs(ofs.c2-ofs.c1);
					if (isTrans) {
						trans++;
					} else {
						if (!ofs.trans) {
							ofs.trans=true;
							trans++;
						}
					}
					break;
				} else {
					if (c1>ofs.c2 && c2>ofs.c1) {
						offset_arr.remove(i);
					} else {
						i++;
					}
				}
			}
			offset_arr.add(new Offset(c1, c2, isTrans));
		} else {
			lcss+=local_cs;
			local_cs=0;
			if (c1!=c2) {
				c1=c2=Math.min(c1,c2);  //using min allows the computation of transpositions
			}
			//if matching characters are found, remove 1 from both cursors (they get incremented at the end of the loop)
			//so that we can have only one code block handling matches
			for (int i = 0; i < maxOffset && (c1+i<l1 || c2+i<l2); i++) {
				if ((c1 + i < l1) && (s1.charAt(c1 + i) == s2.charAt(c2))) {
					c1+= i-1;
					c2--;
					break;
				}
				if ((c2 + i < l2) && (s1.charAt(c1) == s2.charAt(c2 + i))) {
					c1--;
					c2+= i-1;
					break;
				}
			}
		}
		c1++;
		c2++;
		// this covers the case where the last match is on the last token in list, so that it can compute transpositions correctly
		if ((c1 >= l1) || (c2 >= l2)) {
			lcss+=local_cs;
			local_cs=0;
			c1=c2=Math.min(c1,c2);
		}
	}
	lcss+=local_cs;
	return Math.round(Math.max(l1,l2)- lcss +trans); //add the cost of transpositions to the final result
}
```
