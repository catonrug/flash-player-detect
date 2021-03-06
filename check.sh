#!/bin/sh

#this code is tested un fresh 2015-02-09-raspbian-jessie-lite Raspberry Pi image
#by default this script should be located in two subdirecotries under the home

#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get install git -y
#mkdir -p /home/pi/detect && cd /home/pi/detect
#git clone https://github.com/catonrug/flash-player-detect.git && cd flash-player-detect && chmod +x check.sh && ./check.sh

#check if script is located in /home direcotry
pwd | grep "^/home/" > /dev/null
if [ $? -ne 0 ]; then
  echo script must be located in /home direcotry
  return
fi

#it is highly recommended to place this directory in another directory
deep=$(pwd | sed "s/\//\n/g" | grep -v "^$" | wc -l)
if [ $deep -lt 4 ]; then
  echo please place this script in deeper directory
  return
fi

#set application name based on directory name
#this will be used for future temp directory, database name, google upload config, archiving
appname=$(pwd | sed "s/^.*\///g")

#set temp directory in variable based on application name
tmp=$(echo ../tmp/$appname)

#create temp directory
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

#check if database directory has prepared 
if [ ! -d "../db" ]; then
  mkdir -p "../db"
fi

#set database variable
db=$(echo ../db/$appname.db)

#if database file do not exist then create one
if [ ! -f "$db" ]; then
  touch "$db"
fi

#check if google drive config directory has been made
#if the config file exists then use it to upload file in google drive
#if no config file is in the directory there no upload will happen
if [ ! -d "../gd" ]; then
  mkdir -p "../gd"
fi

#create a new array [linklist] with two internet links inside and add one extra line
linklist=$(cat <<EOF
http://fpdownload.macromedia.com/pub/flashplayer/latest/help/install_flash_player_ax.exe
http://fpdownload.macromedia.com/pub/flashplayer/latest/help/install_flash_player.exe
extra line
EOF
)

printf %s "$linklist" | while IFS= read -r url
do {

wget -S --spider -o $tmp/output.log $url

grep -A99 "^Resolving" $tmp/output.log | grep "HTTP.*200 OK"
if [ $? -eq 0 ]; then
#if file request retrieve http code 200 this means OK

grep -A99 "^Resolving" $tmp/output.log | grep "Content-Length" 
if [ $? -eq 0 ]; then
#if there is such thing as Content-Length

grep -A99 "^Resolving" $tmp/output.log | grep "Last-Modified" 
if [ $? -eq 0 ]; then
#if there is such thing as Content-Length

#cut out last modified
lastmodified=$(grep -A99 "^Resolving" $tmp/output.log | grep "Last-Modified" | sed "s/^.*: //")

filename=$(echo $url | sed "s/^.*\///g")

grep "$filename $lastmodified" $db > /dev/null
if [ $? -ne 0 ]; then

echo Downloading $url
wget $url -O $tmp/$filename -q
echo

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
echo

#check if this file is already in database


echo new version detected!
echo

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
echo

#lets put all signs about this file into the database
echo "$filename $lastmodified">> $db
echo "$md5">> $db
echo "$sha1">> $db
echo >> $db

echo searching exact version number
7z x $tmp/$filename -y -o$tmp > /dev/null
version=$(cat $tmp/.rsrc/MANIFEST/1 | \
sed "s/<dependency>/\n<dependency>\n/g" | \
sed "s/<\/assembly>/\n<\/assembly>\n/g" | \
sed "/<dependency>/,/<\/assembly>/d" | \
sed "s/\d034/\n/g" | \
grep "^[0-9]*.\.[0-9]*.\.[0-9]*.\.[0-9]")
echo $version
echo
realurl=$(echo http://fpdownload.adobe.com/get/flashplayer/pdc/$version/$filename)
echo $realurl
echo

#create unique filename for google upload
newfilename=$(echo $filename | sed "s/\.exe/_`echo $version`\.exe/")
mv $tmp/$filename $tmp/$newfilename

#if google drive config exists then upload and delete file:
if [ -f "../gd/$appname.cfg" ]
then
echo Uploading $newfilename to Google Drive..
echo Make sure you have created \"$appname\" direcotry inside it!
../uploader.py "../gd/$appname.cfg" "$tmp/$newfilename"
echo
fi

case "$filename" in
install_flash_player_ax.exe)
name=$(echo "Adobe Flash Player (ActiveX)")
;;
install_flash_player.exe)
name=$(echo "Adobe Flash Player")
;;
esac

#lets send emails to all people in "posting" file
emails=$(cat ../posting | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name $version" "$realurl 
$md5
$sha1"
} done
echo
else
#if file already in database
echo file already in database						
fi

else
#if link do not include Last-Modified
echo Last-Modified field is missing from output.log
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "Last-Modified field is missing from output.log: 
$url"
} done
echo 
echo
fi

else
#if link do not include Content-Length
echo Content-Length field is missing from output.log
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "Content-Length field is missing from output.log: 
$url"
} done
echo 
echo
fi

else
#if http statis code is not 200 ok
echo Did not receive good http status code
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "To Do List" "the following link do not retrieve good http status code: 
$url"
} done
echo 
echo
fi

} done

#clean and remove whole temp direcotry
rm $tmp -rf > /dev/null
