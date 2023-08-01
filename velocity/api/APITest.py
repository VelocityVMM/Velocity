#!python3
import requests
import sys
import random, string

COL_BLU = "\033[94m"
COL_GRN = "\033[92m"
COL_RED = "\033[91m"
COL_CLR = "\033[0m"

letters = string.ascii_letters
username = "".join(random.choice(letters) for i in range(15))
username2 = "".join(random.choice(letters) for i in range(15))
password = "".join(random.choice(letters) for i in range(15))
password2 = "".join(random.choice(letters) for i in range(15))
groupname2 = "".join(random.choice(letters) for i in range(15))

if (len(sys.argv) != 2):
    print("Need the URL for the API!")
    exit(-1)

api_url = sys.argv[1] + "/"
last_resp = None
lat_json = None
authkey = ""

uid = -1
uid2 = -1
gid2 = -1

def p(text):
    print(text, end="", flush=True)

def p_c(col, text):
    p("{}{}{}".format(col, text, COL_CLR))

def p_info(text):
    p_c(COL_BLU, "{}".format(text))

def p_ok(text):
    p_c(COL_GRN, "{}".format(text))

def p_err(text):
    p_c(COL_RED, "{}".format(text))

def pn(text):
    print(text)

def pn_c(col, text):
    pn("{}{}{}".format(col, text, COL_CLR))

def pn_info(text):
    pn_c(COL_BLU, "{}".format(text))

def pn_ok(text):
    pn_c(COL_GRN, "{}".format(text))

def pn_err(text):
    pn_c(COL_RED, "{}".format(text))

def get(endpoint, data):
    global api_url
    global last_resp
    global last_json
    last_resp = requests.get(api_url + endpoint, data=data)
    try:
        json = last_resp.json()
        last_json = json
    except:
        last_json = None
    return last_resp

def put(endpoint, data):
    global api_url
    global last_resp
    global last_json
    last_resp = requests.put(api_url + endpoint, data=data)
    try:
        json = last_resp.json()
        last_json = json
    except:
        last_json = None
    return last_resp

def post(endpoint, data):
    global api_url
    global last_resp
    global last_json
    last_resp = requests.post(api_url + endpoint, data=data)
    try:
        json = last_resp.json()
        last_json = json
    except:
        last_json = None
    return last_resp

def patch(endpoint, data):
    global api_url
    global last_resp
    global last_json
    last_resp = requests.patch(api_url + endpoint, data=data)
    try:
        json = last_resp.json()
        last_json = json
    except:
        last_json = None
    return last_resp

def delete(endpoint, data):
    global api_url
    global last_resp
    global last_json
    last_resp = requests.delete(api_url + endpoint, data=data)
    try:
        json = last_resp.json()
        last_json = json
    except:
        last_json = None
    return last_resp

root_username = input("Root username: ")
root_password = input("Root password: ")

# Authentication
pn_info("Authentication")

p("Logging in as root...")
if (post("u/auth", { "username": root_username, "password": root_password }).status_code == 200):
    p_ok("OK ({})".format(last_resp.status_code))
    root_authkey = last_json["authkey"]
    pn(" - Authkey: {}".format(root_authkey))
else:
    pn_err("FAIL: {}, expected 200".format(last_resp.status_code))

p("Refreshing root authkey...")
if (patch("u/auth", {"authkey": root_authkey}).status_code == 200):
    p_ok("OK ({})".format(last_resp.status_code))
    old_authkey = root_authkey
    root_authkey = last_json["authkey"]
    pn(" - New authkey: {}".format(root_authkey))
else:
    pn_err("FAIL: {}, expected 200".format(last_resp.status_code))

p("Not allowing re-usage of old root authkey...")
if (patch("u/auth", {"authkey": old_authkey}).status_code == 403):
    pn_ok("OK ({})".format(last_resp.status_code))
else:
    pn_err("FAIL: {}, expected 403".format(last_resp.status_code))

p("Dropping root authkey...")
if (delete("u/auth", {"authkey": root_authkey}).status_code == 200):
    pn_ok("OK ({})".format(last_resp.status_code))
else:
    pn_err("FAIL: {}, expected 200".format(last_resp.status_code))

p("Logging in as root...")
if (post("u/auth", { "username": root_username, "password": root_password }).status_code == 200):
    p_ok("OK ({})".format(last_resp.status_code))
    root_authkey = last_json["authkey"]
    pn(" - Authkey: {}".format(root_authkey))
else:
    pn_err("FAIL: {}, expected 200".format(last_resp.status_code))

#
# User and group management
#

pn_info("User and group management")

p("Creating new user '{}' as 'root'...".format(username))
if (put("u/user", {"authkey": root_authkey, "username": username, "password": password, "groups": []}).status_code == 200):
    p_ok("OK ({})".format(last_resp.status_code))
    uid = last_json["uid"]
    pn(" - New uid: {}, groups: {}".format(uid, last_json["groups"]))
else:
    pn_err("FAIL: {}, expected 200".format(last_resp.status_code))

p("Creating new group '{}' as 'root'...".format(groupname2))
if (put("u/group", {"authkey": root_authkey, "groupname": groupname2}).status_code == 200):
    p_ok("OK ({})".format(last_resp.status_code))
    gid2 = last_json["gid"]
    pn(" - New gid: {}".format(gid2))
else:
    pn_err("FAIL: {}, expected 200".format(last_resp.status_code))

p("Logging in as new user '{}'...".format(username))
if (post("u/auth", { "username": username, "password": password}).status_code == 200):
    p_ok("OK ({})".format(last_resp.status_code))
    user_authkey = last_json["authkey"]
    pn(" - Authkey: {}".format(root_authkey))
else:
    pn_err("FAIL: {}, expected 200".format(last_resp.status_code))

p("Not allowing creation of new user '{}' as user '{}'...".format(username, username))
if (put("u/user", {"authkey": user_authkey, "username": username, "password": password, "groups": []}).status_code == 403):
    pn_ok("OK ({})".format(last_resp.status_code))
else:
    pn_err("FAIL: {}, expected 403".format(last_resp.status_code))

p("Not allowing creation of new group '{}' as user '{}'...".format(groupname2, username))
if (put("u/group", {"authkey": user_authkey, "groupname": groupname2}).status_code == 403):
    pn_ok("OK ({})".format(last_resp.status_code))
else:
    pn_err("FAIL: {}, expected 403".format(last_resp.status_code))

p("Not allowing duplication of user '{}' as 'root'...".format(username))
if (put("u/user", {"authkey": root_authkey, "username": username, "password": password, "groups": []}).status_code == 409):
    pn_ok("OK ({})".format(last_resp.status_code))
else:
    pn_err("FAIL: {}, expected 409".format(last_resp.status_code))

p("Not allowing duplication of group '{}' as 'root'...".format(groupname2))
if (put("u/group", {"authkey": root_authkey, "groupname": groupname2}).status_code == 409):
    pn_ok("OK ({})".format(last_resp.status_code))
else:
    pn_err("FAIL: {}, expected 409".format(last_resp.status_code))

p("Creating new user '{}' as 'root'...".format(username2))
if (put("u/user", {"authkey": root_authkey, "username": username2, "password": password2, "groups": []}).status_code == 200):
    p_ok("OK ({})".format(last_resp.status_code))
    uid2 = last_json["uid"]
    pn(" - New uid: {}, groups: {}".format(uid, last_json["groups"]))
else:
    pn_err("FAIL: {}, expected 200".format(last_resp.status_code))

p("Logging in as new user '{}'...".format(username2))
if (post("u/auth", {"username": username2, "password": password2}).status_code == 200):
    p_ok("OK ({})".format(last_resp.status_code))
    user2_authkey = last_json["authkey"]
    pn(" - Authkey: {}".format(root_authkey))
else:
    pn_err("FAIL: {}, expected 200".format(last_resp.status_code))

p("Not allowing deletion of newly created user '{}' as '{}'...".format(username2, username))
if (delete("u/user", {"authkey": user_authkey, "uid": uid2}).status_code == 403):
    pn_ok("OK ({})".format(last_resp.status_code))
else:
    pn_err("FAIL: {}, expected 403".format(last_resp.status_code))

p("Not allowing deletion of newly created group '{}' as '{}'...".format(groupname2, username))
if (delete("u/group", {"authkey": user_authkey, "gid": gid2}).status_code == 403):
    pn_ok("OK ({})".format(last_resp.status_code))
else:
    pn_err("FAIL: {}, expected 403".format(last_resp.status_code))

p("Deleting newly created user '{}' as 'root'...".format(username2))
if (delete("u/user", {"authkey": root_authkey, "uid": uid2}).status_code == 200):
    pn_ok("OK ({})".format(last_resp.status_code))
else:
    pn_err("FAIL: {}, expected 200".format(last_resp.status_code))

p("Deleting newly created group '{}' as 'root'...".format(groupname2))
if (delete("u/group", {"authkey": root_authkey, "gid": gid2}).status_code == 200):
    pn_ok("OK ({})".format(last_resp.status_code))
else:
    pn_err("FAIL: {}, expected 200".format(last_resp.status_code))

p("Not allowing refresh of key of deleted user {}...".format(username2))
if (patch("u/auth", {"authkey": user2_authkey}).status_code == 403):
    pn_ok("OK ({})".format(last_resp.status_code))
else:
    pn_err("FAIL: {}, expected 403".format(last_resp.status_code))

p("Assigning user {} to group 'usermanager' as 'root'...".format(username))
if (put("u/group/assign", {"authkey": root_authkey, "uid": uid, "groups": [1]}).status_code == 200):
    p_ok("OK ({})".format(last_resp.status_code))
    pn(" - groups: {}".format(last_json["groups"]))
else:
    pn_err("FAIL: {}, expected 200".format(last_resp.status_code))

p("Creating new user '{}' as '{}'...".format(username2, username))
if (put("u/user", {"authkey": user_authkey, "username": username2, "password": password2, "groups": []}).status_code == 200):
    p_ok("OK ({})".format(last_resp.status_code))
    uid2 = last_json["uid"]
    pn(" - New uid: {}, groups: {}".format(uid, last_json["groups"]))
else:
    pn_err("FAIL: {}, expected 200".format(last_resp.status_code))

p("Creating new group '{}' as '{}'...".format(groupname2, username))
if (put("u/group", {"authkey": user_authkey, "groupname": groupname2}).status_code == 200):
    p_ok("OK ({})".format(last_resp.status_code))
    gid2 = last_json["gid"]
    pn(" - New gid: {}".format(gid2))
else:
    pn_err("FAIL: {}, expected 200".format(last_resp.status_code))

p("Assigning user {} to group 'usermanager' as '{}'...".format(username2, username))
if (put("u/group/assign", {"authkey": user_authkey, "uid": uid, "groups": [1]}).status_code == 200):
    p_ok("OK ({})".format(last_resp.status_code))
    pn(" - groups: {}".format(last_json["groups"]))
else:
    pn_err("FAIL: {}, expected 200".format(last_resp.status_code))

p("Not allowing to assign user {} to group 'root' as '{}'...".format(username2, username))
if (put("u/group/assign", {"authkey": user_authkey, "uid": uid2, "groups": [0]}).status_code == 406):
    pn_ok("OK ({})".format(last_resp.status_code))
else:
    pn_err("FAIL: {}, expected 406".format(last_resp.status_code))

p("Deleting newly created user '{}' as '{}'...".format(username2, username))
if (delete("u/user", {"authkey": user_authkey, "uid": uid2}).status_code == 200):
    pn_ok("OK ({})".format(last_resp.status_code))
else:
    pn_err("FAIL: {}, expected 200".format(last_resp.status_code))

p("Deleting newly created group '{}' as '{}'...".format(groupname2, username))
if (delete("u/group", {"authkey": user_authkey, "gid": gid2}).status_code == 200):
    pn_ok("OK ({})".format(last_resp.status_code))
else:
    pn_err("FAIL: {}, expected 200".format(last_resp.status_code))

p("Removing user {} from group 'usermanager' as 'root'...".format(username))
if (delete("u/group/assign", {"authkey": root_authkey, "uid": uid, "groups": [1]}).status_code == 200):
    p_ok("OK ({})".format(last_resp.status_code))
    pn(" - groups: {}".format(last_json["groups"]))
else:
    pn_err("FAIL: {}, expected 200".format(last_resp.status_code))

p("Not allowing creation of new user '{}' as user '{}' after removal...".format(username, username))
if (put("u/user", {"authkey": user_authkey, "username": username, "password": password, "groups": []}).status_code == 403):
    pn_ok("OK ({})".format(last_resp.status_code))
else:
    pn_err("FAIL: {}, expected 403".format(last_resp.status_code))

p("Not allowing creation of new group '{}' as user '{}' after removal...".format(groupname2, username))
if (put("u/group", {"authkey": user_authkey, "groupname": groupname2}).status_code == 403):
    pn_ok("OK ({})".format(last_resp.status_code))
else:
    pn_err("FAIL: {}, expected 403".format(last_resp.status_code))
