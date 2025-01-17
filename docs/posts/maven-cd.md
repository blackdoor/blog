---
date: 2016-08-08
authors: [nathan]
description: >
  Our new blog is built with the brand new built-in blog plugin. You can build
  a blog alongside your documentation or standalone
categories:
  - Blog
---

# Complete guide to continuous deployment to maven central from Travis CI.
<!-- more -->

Continuous deployment is a very useful tool for open source projects. The people accepting pull requests in an open source project may not all have the permissions or skills to also deploy those changes, but continuous deployment offers them a way around that. Once code is accepted into the master branch, that code is deployed automatically. This allows individuals deploying pull requests to add agile features and make bug fixes without taking up too much time.

This guide will take your maven library project from creation and local installation to creation and code-signing in the cloud, where it is then deployed to maven central. We make a few assumptions about your starting point:

* Your project already is a valid maven project (if it's not, see [here](https://maven.apache.org/guides/getting-started/maven-in-five-minutes.html))
* Your project is hosted on github (if not, [create a repo](https://help.github.com/articles/create-a-repo/))
* You are using Linux, OSX or other *nix system with bash
* You have gpg installed and available on the path
* You have the travis command line client installed ([`gem install travis`](https://github.com/travis-ci/travis.rb#readme))

## Obtain OSSRH account

OSSRH is a free host for open source projects in maven central. If you do not already have an account, follow the [instructions for initial setup](http://central.sonatype.org/pages/ossrh-guide.html#initial-setup) and ensure you get a confirmation email. You should use a domain you own for the group id, such as `com.mysite`. If you do not have a domain, it is also popular to use your github domain, such as `io.github.username`.

## Configure maven project for upload to OSSRH

Before we can start to consider uploading, we need to ensure our project has all the information it needs to be a quality library. We need to fill out the following fields in our pom.xml:

* `name` - the name of the project
* `description` - a short description
* `url` - location where users can go to get more information about the library
* `licences` - self explanatory
* `scm` - source control information
* `developers` - who worked on the project

Once complete, these might look like this:

```xml
<name>my library</name>
<description>A library.</description>
<url>https://username.github.io/project</url>
<licenses>
    <license>
        <name>MIT License</name>
        <url>http://www.opensource.org/licenses/mit-license.php</url>
        <distribution>repo</distribution>
    </license>
</licenses>
    
<scm>
    <url>https://github.com/username/project</url>
    <connection>scm:git:git://github.com/username/project.git</connection>
    <developerConnection>scm:git:git@github.com:username/project.git</developerConnection>
</scm>
    
<developers>
    <developer>
        <id>username</id>
        <name>John Doe</name>
        <email>jdoe@email.com</email>
    </developer>
</developers>
```

In order to deploy to central, we need maven to do four things (called plugins in maven) above and beyond its usual role: 

* sign
* package docs
* package source
* staging

First lets add a couple bits needed by ossrh. The first part will tell the staging plugin where to deploy. The second part tells how to deploy and `autoReleaseAfterClose` instructs the plugin to finalize our deployment after upload.

```xml
<distributionManagement>
    <snapshotRepository>
        <id>ossrh</id>
        <url>https://oss.sonatype.org/content/repositories/snapshots</url>
    </snapshotRepository>
</distributionManagement>
<build>
    ...
        <plugin>
            <groupId>org.sonatype.plugins</groupId>
            <artifactId>nexus-staging-maven-plugin</artifactId>
            <version>1.6.6</version>
            <extensions>true</extensions>
            <configuration>
                <serverId>ossrh</serverId>
                <nexusUrl>https://oss.sonatype.org/</nexusUrl>
                <autoReleaseAfterClose>true</autoReleaseAfterClose>
            </configuration>
        </plugin>
    </plugins>
    ...
</build>
```

We don't want this to happen every time we build the project on maven, so we will create profiles. This enables us to choose what plugins to use.  
Create a profile for code signing by adding the following to your `pom.xml`

```xml
<profiles>
    ...
    <profile>
        <id>sign</id>
        <build>
            <plugins>
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-gpg-plugin</artifactId>
                    <version>1.6</version>
                    <executions>
                        <execution>
                            <id>sign-artifacts</id>
                            <phase>verify</phase>
                            <goals>
                                <goal>sign</goal>
                            </goals>
                        </execution>
                    </executions>
                </plugin>
            </plugins>
        </build>
    </profile>
    ...
</profiles>
```

Create a profile for packaging sources and docs by adding the following to your `pom.xml`

```xml
<profiles>
    ...
    <profile>
        <id>build-extras</id>
        <activation>
            <activeByDefault>true</activeByDefault>
        </activation>
        <build>
            <plugins>
                <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-source-plugin</artifactId>
                    <version>2.4</version>
                    <executions>
                        <execution>
                            <id>attach-sources</id>
                            <goals>
                                <goal>jar-no-fork</goal>
                            </goals>
                        </execution>
                    </executions>
                </plugin>
                    <plugin>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-javadoc-plugin</artifactId>
                    <version>2.10.3</version>
                    <executions>
                        <execution>
                            <id>attach-javadocs</id>
                            <goals>
                                <goal>jar</goal>
                            </goals>
                        </execution>
                    </executions>
                </plugin>
            </plugins>
        </build>
    </profile>
    ...
</profiles>
```

Next we need to provide some information to those plugins so they can run. The primary piece of information needed is our ossrh credentials as well as what certificate should be used to sign our code. To do this, we will use a separate settings file. Create a new folder for our deployment files `$ mkdir cd`. Create our settings file at `cd/mvnsettings.xml`. Add the following to the file:

```xml
<settings>
  <servers>
    <server>
      <id>ossrh</id>
      <username>${env.OSSRH_JIRA_USERNAME}</username>
      <password>${env.OSSRH_JIRA_PASSWORD}</password>
    </server>
  </servers>
  
  <profiles>
    <profile>
      <id>ossrh</id>
      <activation>
        <activeByDefault>true</activeByDefault>
      </activation>
      <properties>
        <gpg.executable>gpg</gpg.executable>
        <gpg.keyname>${env.GPG_KEY_NAME}</gpg.keyname>
        <gpg.passphrase>${env.GPG_PASSPHRASE}</gpg.passphrase>
      </properties>

    </profile>
  </profiles>
</settings>
```

Maven supports environment variables in its settings files, so the `${env.VAR}` fields tell maven to fill the field with the value in the environment variable `VAR`.
We will define these variables later in travis as encrypted environment variables.

## Create code signing cert

### Create master key

Now we need to create a certificate with which to sign our code. If you already have a gpg certificate, skip to "Create signing sub-key".

Create a master key with `$ gpg --gen-key`.  
Select `RSA and RSA`, or `ECDSA` if it's available.  
Enter the maximum key size (`4096` for `RSA`).  
Enter `0` for no key expiration.  
Enter your information.  
Choose a strong passphrase (see [diceware](https://en.wikipedia.org/wiki/Diceware) if you're not sure how to pick a strong passphrase).

This master key will act as your digital identity for the rest of your life, so take good care of it. 

### Create signing sub-key

Our master key is super important to us, and we would never entrust it to "the cloud", so we need to create a more controllable sub-key. This sub-key will be used to sign our code.  
To add a sub-key, begin to edit the master key we just created with  
`$ gpg --edit-key your@email.com`  
(where `your@email.com` was the email you set for the master key)  
Type `addkey`. Choose one of the options marked as `(sign only)`, probably `RSA`.  
Enter the maximum key size (`4096` for `RSA`).  
Enter a reasonable expiration. Perhaps `20y`.  
Type `save`.

### Publish key

To ensure our keys are not revoked, ossrh will look to one of a set of keyservers. In order to enable that, we need to upload our (public) keys so ossrh can see them. We will upload our keys to both the MIT and Ubuntu key servers for redundancy.

#### Find your key id

Use `$ gpg --list-keys` to see all they keys in your keyring. One of the entries should look something like this

```
pub   4096R/$keyid 2015-05-29 [expires: whenever]
uid       [ unknown] Your Name <your@email.com>
... more stuff
```

> update: in newer versions of gpg your list-keys output may look more like this
```
pub   rsa4096 2015-05-29 [SC] [expires: whenever]
      $keyid
uid           [ unknown] Your Name <your@email.com>
```

The string in place of `$keyid` is your key id.  
Submit your key to the ubuntu server with  
`$ gpg --send-keys --keyserver keyserver.ubuntu.com $keyid`  
Submit your key to the MIT server with  
`$ gpg --send-keys --keyserver pgp.mit.edu $keyid`  
And once more just to be sure  
`$ gpg --send-keys --keyserver pool.sks-keyservers.net $keyid`  

### Remove master keys

#### Backup

Now would be a good (read: critical) time to back up your keys. Best practices for backing up keys are beyond the scope of this guide, but backing them up to a paper copy and storing that in a physically secure location is recommended.  
Export your public keys with  
`$ gpg --export --armor your@email.com > mysupersecretkey.asc`  
Append your private keys to the same file with  
`$ gpg --export-secret-keys --armor your@email.com >> mysupersecretkey.asc`  

Now put `mysupersecretkey.asc` somewhere very safe and destroy the file (use `$ shred --remove mysupersecretkey.asc` for destruction)

#### Export sub-keys

`$ gpg --export-secret-subkeys your@email.com > subkeys`

#### Remove master keys

`$ gpg --delete-secret-key your@email.com`

#### Import sub-keys and clean up 

Import your sub-keys back with `$ gpg --import subkeys`  
Shred the export `$ shred --remove subkeys`  
Now you should have only the private encryption key and our private code signing key left. We also want to delete the encryption key, as that is what people will use to send you secret messages and there is no place for that in code signing.
Edit your key again `$ gpg --edit-key your@email.com`  
You should see the keys available, and one of the lines will look like this  
`sub  4096R/DEADBEEF  created: 2015-04-26  expires: 2025-04-27  usage: E`  
Note specifically the `sub` at the beginning of the line, and the `E` on the end of the line. These indicate that it is an encrypting subkey. 
Type `key n` where `n` is the index of the private encryption sub-key to select that key. You should now see a `*` next to the line with that key. If the `*` is next to the wrong line, just type `key 0` to clear the selection and try again. Now that you're sure the right line is selected, type `delkey` to delete that key. Type `save` to finish.  
Now you should see something like the following when you use `$ gpg --list-secret-keys`  

```
sec#   4096R/$keyid 2015-05-29 [expires: sometime]
uid                  Your Name <your@email.com>
ssb   4096R/DEADBEEF 2015-05-29
```

The `#` after the `sec` tells you that the secret signing master key is not in the keyring and the single `ssb` (SecretSuBkey) indicates that there is only one secret subkey.

#### Change passphrase

Finally we will change the passphrase. This prevents someone from accessing your main key. If someone compromises the passphrase on CI, it will have nothing to do with the passphrase to your main key.

```
$ gpg --edit-key your@email.com
passwd
save
```

## Encrypt cert and variables for travis

### Encrypt cert

Login to travis if you have not yet `$ travis login`
Now let's export our cert so we can encrypt it for travis.

```
$ gpg --export --armor your@email.com > codesigning.asc
$ gpg --export-secret-keys --armor your@email.com >> codesigning.asc
```

Make sure your working directory is the git root of your project.  
Encrypt the keys `$ travis encrypt-file codesigning.asc`  
Take note of the line that looks like `openssl aes-256-cbc -K...`  
Shred the un-encrypted keys `$ shred --remove codesigning.asc`  
Make sure to move the created file to `cd/codesigning.asc.enc`

We want to be able to decrypt that file once we are on Travis CI, so we will create a script to do that for us. Create a file at `cd/before-deploy.sh` with the content: 

```
#!/usr/bin/env bash
if [ "$TRAVIS_BRANCH" = 'master' ] && [ "$TRAVIS_PULL_REQUEST" == 'false' ]; then
    openssl aes-256-cbc -K $encrypted_SOME_key -iv $encrypted_SOME_iv -in cd/signingkey.asc.enc -out cd/signingkey.asc -d
    gpg --fast-import cd/signingkey.asc
fi
```

where the `openssl` line is the one you took note of earlier.

### Encrypt variables

Encrypt environment variables using `$  travis encrypt MY_SECRET_ENV=super_secret`. We need to encrypt the variables we used earlier in the `mvnsettings.xml`. Once again, those were

* `OSSRH_JIRA_USERNAME`
* `OSSRH_JIRA_PASSWORD`
* `GPG_KEY_NAME` - the email address on your cert
* `GPG_PASSPHRASE` - the passphrase we set for our cert

Use the travis CLI to encrypt those and take note of the output of each command.

## Create `.travis.yml`

Next we will need a `.travis.yml` file to tell Travis CI what to do with our project. Our file will look something like this

```
language: java
env:
  global:
    - secure: "the base64 string from when you encrypted OSSRH_JIRA_USERNAME"
    - # ^^ OSSRH_JIRA_USERNAME
    - secure: "the base64 string from when you encrypted OSSRH_JIRA_PASSWORD"
    - # ^^ OSSRH_JIRA_PASSWORD
    - secure: "the base64 string from when you encrypted GPG_KEY_NAME"
    - # ^^ GPG_KEY_NAME
    - secure: "the base64 string from when you encrypted GPG_PASSPHRASE"
    - # ^^ GPG_PASSPHRASE

install: mvn install -P !build-extras -DskipTests=true -Dmaven.javadoc.skip=true -B -V
script: mvn test -P !build-extras -B

cache:
  directories:
    - ~/.m2/repository

after_success:
  - ./cd/before-deploy.sh
  - ./cd/deploy.sh
```

The `after_success` section lets us define commands we want to run if all the builds and tests pass. We use it to run the script we made which decrypts our certificate, as well as a script that will do our deployment.

## Create deploy script

We called a deploy script in the `after_success` section of our `.travis.yml`. We will define that file now, so create the file `cd/deploy.sh` with the content: 

```
#!/usr/bin/env bash
if [ "$TRAVIS_BRANCH" = 'master' ] && [ "$TRAVIS_PULL_REQUEST" == 'false' ]; then
    mvn deploy -P sign,build-extras --settings cd/mvnsettings.xml
fi
```

This tells Travis that if we're on the `master` branch and this is not a pull request, it should deploy the project to maven while making sure to use the `sign` and `build-extras` profiles and any settings in our settings file.

If all goes well, we should be able to check this into our master branch, see it run on Travis CI and see our code on maven central.

If you have any questions, or tips on how to improve the guide, feel free to contact me at nfischer921@gmail.com

## Resources

* https://alexcabal.com/creating-the-perfect-gpg-keypair/
* https://maven.apache.org/plugins/maven-gpg-plugin/sign-mojo.html
* https://www.gnupg.org/documentation/manpage.html
* https://www.theguardian.com/info/developer-blog/2014/sep/16/shipping-from-github-to-maven-central-and-s3-using-travis-ci
* https://docs.travis-ci.com/user/environment-variables/#Encrypted-Variables
* https://docs.travis-ci.com/user/customizing-the-build/
* https://docs.travis-ci.com/user/encrypting-files/
