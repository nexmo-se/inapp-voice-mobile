import { neru } from 'neru-alpha';
import express from 'express';
import * as dotenv from 'dotenv';
import axios from 'axios';
import cors from 'cors';
import {tokenGenerate} from '@vonage/jwt';
import fs from 'fs';
import admin from "firebase-admin";

admin.initializeApp({ credential: admin.credential.cert(process.env.GOOGLE_APPLICATION_CREDENTIALS), projectId: 'inapp-voice-android' }); 
dotenv.config()

const port = process.env.NERU_APP_PORT || process.env.PORT || 3003; 
const app = express();
app.use(express.json());
app.use(cors());

// const REGIONS = ["virginia", "oregon", "dublin", "frankfurt", "singapore", "sydney"]
// const DATA_CENTER = {
//   virginia:	"https://api-us-3.vonage.com",
//   oregon: "https://api-us-4.vonage.com",
//   dublin:	"https://api-eu-3.vonage.com",
//   frankfurt:	"https://api-eu-4.vonage.com",
//   singapore:	"https://api-ap-3.vonage.com",
//   sydney:	"https://api-ap-4.vonage.com"
// }


// const WEBSOCKET = {
//   virginia:	"wss://ws-us-3.vonage.com",
//   oregon:	"wss://ws-us-4.vonage.com",
//   dublin: "wss://ws-eu-3.vonage.com",
//   frankfurt:	"wss://ws-eu-4.vonage.com",  
//   singapore:	"wss://ws-ap-3.vonage.com",
//   sydney:	"wss://ws-ap-4.vonage.com"
// }

const REGIONS = ["US", "EU", "APAC"]

const DATA_CENTER = {
  US:	"https://api-us-3.vonage.com",
  EU:	"https://api-eu-3.vonage.com",
  APAC:	"https://api-ap-3.vonage.com"
}

const WEBSOCKET = {
  US:	"wss://ws-us-3.vonage.com",
  EU: "wss://ws-eu-3.vonage.com",
  APAC:	"wss://ws-ap-3.vonage.com"
}

const BUSY_STATE = ['answered']
const IDLE_STATE = ['busy', 'cancelled', 'unanswered', 'disconnected', 'rejected', 'failed', 'timeout', 'completed']

const BUSY_CONV_STATE_KEY = 'busyConv'
const FCM_TOKEN_STATE_KEY = 'fcmToken'

const API_VERSION = 'v0.3'

const applicationId = neru.config.apiApplicationId || process.env.APPLICATION_ID
const privateKey = neru.config.privateKey || fs.readFileSync(process.env.PRIVATE_KEY);

const aclPaths = {
    "paths": {
      "/*/users/**": {},
      "/*/conversations/**": {},
      "/*/sessions/**": {},
      "/*/devices/**": {},
      "/*/image/**": {},
      "/*/media/**": {},
      "/*/applications/**": {},
      "/*/push/**": {},
      "/*/knocking/**": {},
      "/*/legs/**": {}
    }
}

app.use(express.static('public'))

app.get('/_/health', async (req, res) => {
    res.sendStatus(200);
});

app.get('/', async (req, res, next) => {
    res.send('hello world').status(200);
});

app.post('/getCredential', async (req, res) => {
  const {username, region, pin , token} = req.body;
  if (!username || !region || !(pin || token )|| !REGIONS.includes(region.toUpperCase())) {
    console.log("getCredential missing information error")
    return res.status(501).end()
  }

  if (pin && pin != process.env.LOGIN_PIN) {
    console.log("getCredential wrong pin")
    return res.status(501).end()
  }

  if (token) {
    let tokenDecode = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
  
    if (tokenDecode.application_id !== applicationId) {
      console.log("getCredential wrong token: ", tokenDecode)
      return res.status(501).end()
    }
  }

  const selectedRegion = region.toUpperCase()
  const restAPI = `${DATA_CENTER[selectedRegion]}/${API_VERSION}`
  const websocket = WEBSOCKET[selectedRegion]

  // Remove user from busy state
  const instanceState = neru.getInstanceState();

  const busyConv = await instanceState.hget(BUSY_CONV_STATE_KEY, selectedRegion);
  if (busyConv) {
    let busyConvJson = JSON.parse(busyConv)
    let index = busyConvJson.findIndex((conv) => conv.users && conv.users.includes(username))
    if (index > -1) {
      busyConvJson.splice(index, 1);
      await instanceState.hset(BUSY_CONV_STATE_KEY, { [region]: JSON.stringify(busyConvJson) });
      // Notify frontend
      notifyUsers(region)
    }
  }

  axios.get(`${restAPI}/users?name=${username}`, { headers: {"Authorization" : `Bearer ${generateJwt()}`} })
  .then(async (result) => {
      console.log("user exist", result.data._embedded.users[0].name)
      const jwt = generateJwt(username) 
      return res.status(200).json({ username, userId: result.data._embedded.users[0].id, region, dc: DATA_CENTER[selectedRegion], ws: websocket, token: jwt});
  })
  .catch(error => {
    axios.post(`${restAPI}/users`, {
      "name":  username,
      "display_name": username
    } , { headers: {"Authorization" : `Bearer ${generateJwt()}`} })
    .then(async (result) => {
      console.log("user not exist",result.data.name)
      const jwt = generateJwt(username)

      notifyUsers(region)
      return res.status(200).json({username, userId: result.data.id, region, dc: DATA_CENTER[selectedRegion], ws: websocket, token: jwt});
    }).catch(error => {
      console.log("register error", error)
        res.status(501).send()
    })      
  })
});

app.post('/getMembers', (req, res) => {
  const {dc, username, token} = req.body;
  if (!dc || !username || !token) {
    console.log("getMembers missing information error")
    return res.status(501).end()
  }
  let tokenDecode = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());

  if (tokenDecode.application_id !== applicationId) {
    console.log("getMembers wrong token: ", tokenDecode)
    return res.status(501).end()
  }

  const restAPI = `${dc}/${API_VERSION}`

  axios.get(`${restAPI}/users?page_size=100`, { headers: {"Authorization" : `Bearer ${generateJwt()}`} })
  .then(async (result) => {
    // Get busy users
    const region = Object.keys(DATA_CENTER).find(key => DATA_CENTER[key] === dc);
    const instanceState = neru.getInstanceState();
    const busyConv = await instanceState.hget(BUSY_CONV_STATE_KEY, region);
    let busyUsers = []
    if (busyConv) {
      const busyConvJson = JSON.parse(busyConv)
      busyConvJson.forEach((conv) => {
      busyUsers = busyUsers.concat(conv.users)
      })
    }
    
    const uniqueBusyUsers = [...new Set(busyUsers)];
    const availableMembers = result.data._embedded.users
      .filter((member) => member.name !== username && !uniqueBusyUsers.includes(member.name))
      .map((member) => member.name)

    const busyMembers = result.data._embedded.users
    .filter((member) => member.name !== username && uniqueBusyUsers.includes(member.name))
    .map((member) => member.name)
       
    return res.status(200).json({members: {
      available: availableMembers,
      busy: busyMembers
    }
    });
  })
  .catch(error => {
    console.log("get members error: ", error)
    res.status(501).send()
  })
});

app.delete('/deleteUser', async (req, res) => {
  const {dc, userId, token} = req.body;
  if (!dc || !userId || !token) {
    console.log("deleteUser missing information error")
    return res.status(501).end()
  }
  let tokenDecode = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());

  if (tokenDecode.application_id !== applicationId) {
    console.log("deleteUser wrong token: ", tokenDecode)
    return res.status(501).end()
  }

  const region = Object.keys(DATA_CENTER).find(key => DATA_CENTER[key] === dc);
  const restAPI = `${dc}/${API_VERSION}`

  try {
    await deleteUser(restAPI, userId)
    notifyUsers(region)
    return res.status(200).end()
  } catch (error) {
    console.log("deleteuser error:", error)
    return res.status(501).end()
  }
})

app.delete('/deleteAllUsers', (req, res) => {
  const {dc, token} = req.body;
  if (!dc || !token) {
    console.log("deleteAllUsers missing information error")
    return res.status(501).end()
  }
  let tokenDecode = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());

  if (tokenDecode.application_id !== applicationId) {
    console.log("deleteAllUsers wrong token: ", tokenDecode)
    return res.status(501).end()
  }

  const restAPI = `${dc}/${API_VERSION}`

  axios.get(`${restAPI}/users?page_size=100`, { headers: {"Authorization" : `Bearer ${generateJwt()}`} })
  .then(async (result) => {
      const memberIds = result.data._embedded.users
        .map((member) => member.id)
      
      memberIds.forEach(async (userId) => {
        try {
          await deleteUser(restAPI, userId)
        } catch (error) {
          console.log("deleteAllUsers error:", error)
        }
      });

      return res.status(200).send();
  })
  .catch(error => {
    console.log("deleteAllUsers error: ", error)
    res.status(501).send()
  })
})

app.delete('/clearBusyUsers', async (req, res) => {
  const {region, token} = req.body;
  if (!region || !token || !REGIONS.includes(region.toUpperCase())) {
    console.log("clearBusyUsers missing information error")
    return res.status(501).end()
  }
  let tokenDecode = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());

  if (tokenDecode.application_id !== applicationId) {
    console.log("clearBusyUsers wrong token: ", tokenDecode)
    return res.status(501).end()
  }

  const instanceState = neru.getInstanceState();
  await instanceState.hset(BUSY_CONV_STATE_KEY, { [region]: null });
  return res.status(200).send();
  
})

app.delete('/clearFcmTokens', async (req, res) => {
  const {region, token} = req.body;
  if (!region || !token || !REGIONS.includes(region.toUpperCase())) {
    console.log("clearFcmTokens missing information error")
    return res.status(501).end()
  }
  let tokenDecode = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
  
  if (tokenDecode.application_id !== applicationId) {
    console.log("clearFcmTokens wrong token: ", tokenDecode)
    return res.status(501).end()
  }
  
  const instanceState = neru.getInstanceState();
  await instanceState.hset(FCM_TOKEN_STATE_KEY, { [region]: null });
  return res.status(200).send();
  
})

app.post('/registerFcm', async (req, res) => {
  const {dc, token, fcmToken} = req.body;
  if (!dc || !token || !fcmToken) {
    console.log("registerFcm missing information error")
    return res.status(501).end()
  }
  
  let tokenDecode = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
  
  if (tokenDecode.application_id !== applicationId) {
    console.log("registerFcm wrong token: ", tokenDecode)
    return res.status(501).end()
  }
  
  const region = Object.keys(DATA_CENTER).find(key => DATA_CENTER[key] === dc);
  if (region) {
    let data = {
      username: tokenDecode.sub,
      fcmToken: fcmToken
    }
    const instanceState = neru.getInstanceState();
    const fcmData = await instanceState.hget(FCM_TOKEN_STATE_KEY, region);
    if (fcmData) {
      let fcmDataJson = JSON.parse(fcmData)
      let existFcmIndex = fcmDataJson.findIndex((fcm) => fcm.username == tokenDecode.sub)
      if (existFcmIndex > -1) {
        fcmDataJson[existFcmIndex]['fcmToken'] = fcmToken
      }
      else {
        fcmDataJson.push(data)
      }
      await instanceState.hset(FCM_TOKEN_STATE_KEY, { [region]: JSON.stringify(fcmDataJson) });
    }
    else {
      await instanceState.hset(FCM_TOKEN_STATE_KEY, { [region]: JSON.stringify([data])});
    }
  }
  else {
    return res.status(200).send();
  }
})

app.post('/unregisterFcm', async (req, res) => {
  const {dc, token} = req.body;
  if (!dc || !token) {
    console.log("unregisterFcm missing information error")
    return res.status(501).end()
  }
  
  let tokenDecode = JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString());
  
  if (tokenDecode.application_id !== applicationId) {
    console.log("registerFcm wrong token: ", tokenDecode)
    return res.status(501).end()
  }
  const region = Object.keys(DATA_CENTER).find(key => DATA_CENTER[key] === dc);
  if (region) {
    const instanceState = neru.getInstanceState();
    const fcmData = await instanceState.hget(FCM_TOKEN_STATE_KEY, region);
    if (fcmData) {
      let fcmDataJson = JSON.parse(fcmData)
      let index = fcmDataJson.findIndex((fcm) => fcm.username == tokenDecode.sub)
      if (index > -1) {
        fcmDataJson.splice(index, 1);
        await instanceState.hset(FCM_TOKEN_STATE_KEY, { [region]: JSON.stringify(fcmDataJson) });
      }
    }
    else {
      return res.status(200).send();
    }
  }
  else {
    return res.status(200).send();
  }
})

app.post('/notifyUser', async (req, res) => {
  const {region} = req.body;
  if (!region || !REGIONS.includes(region.toUpperCase())) {
    console.log("notifyUser missing information error")
    return res.status(501).end()
  }
  
  notifyUsers(region)
  res.status(200).send()
})

function generateJwt(username) {
  if (!username) {
    const adminJwt = tokenGenerate(applicationId, privateKey, {
      //expire in 24 hours
      exp: Math.round(new Date().getTime()/1000)+86400,
      acl: aclPaths
    });
    return adminJwt
  }
  
  const jwt = tokenGenerate(applicationId, privateKey, {
    sub: username,
    //expire in 3 days
    exp: Math.round(new Date().getTime()/1000)+259200,
    acl: aclPaths
    });

  return jwt
}

function deleteUser(restAPI, userId) {
  return new Promise((resolve, reject) => {
    axios.delete(`${restAPI}/users/${userId}`, { headers: {"Authorization" : `Bearer ${generateJwt()}`} })
    .then(async (result) => {
        console.log("user deleted")
        resolve()
    })
    .catch(error => {
        console.log("delete user error: ", error)
        reject(error)
    })
  })
}

async function notifyUsers(region) {
  if (!region) return
  
  const instanceState = neru.getInstanceState();
  const fcmData = await instanceState.hget(FCM_TOKEN_STATE_KEY, region);
  if (fcmData) {
    let fcmDataJson = JSON.parse(fcmData)
    const registrationTokens = fcmDataJson.map((fcmData) => {
    return fcmData.fcmToken
    })
  
    if (registrationTokens.length == 0) {
      return
    }
    const message = {
      data: {message: 'updateUsersState'},
      tokens: registrationTokens,
    };

    admin
    .messaging()
    .sendMulticast(message)
    .then((response) => {
      // Response is a message ID string.
      console.log("Successfully sent message:", response);
    })
    .catch((error) => {
      console.log("Error sending message:", error);
    });
  }
  else {
    return
  }
}

app.get('/voice/answer', async (req, res) => {
  console.log('NCCO request:');
  console.log(`  - caller: ${req.query.from}`);
  console.log(`  - callee: ${req.query.to}`);
  console.log('---');
  var ncco = [{"action": "talk", "text": "No destination user - hanging up"}];
  var username = req.query.to;
  if (username) {
    ncco = [
      {
        "action": "connect",
        "ringbackTone":"https://cdn.newvoicemedia.com/webrtc-audio/us-ringback.mp3",
        "endpoint": [
          {
            "type": "app",
            "user": username
          }
        ],
        "timeout": 20
      }
    ]

    // Add to busy state
    const region = Object.keys(DATA_CENTER).find(key => DATA_CENTER[key] === req.query.region_url);
    if (region) {
      const instanceState = neru.getInstanceState();
      const busyConv = await instanceState.hget(BUSY_CONV_STATE_KEY, region);

      let data = {
        conversationId: req.query.conversation_uuid,
        users: []
      }
      if (busyConv) {
        let busyConvJson = JSON.parse(busyConv)
        let existBusyUsers = busyConvJson.findIndex((conv) => conv.conversationId == req.query.conversation_uuid)
        if (existBusyUsers > -1) {
          busyConvJson[existBusyUsers]['users'] = data.users
        }
        else {
          busyConvJson.push(data)
        }
        await instanceState.hset(BUSY_CONV_STATE_KEY, { [region]: JSON.stringify(busyConvJson) });

      } else {
        await instanceState.hset(BUSY_CONV_STATE_KEY, { [region]: JSON.stringify([data]) });
      }
    }
  }
  res.json(ncco);
});

app.all('/voice/event', async (req, res) => {
  console.log('EVENT: ', req.body);

  // Update user from busy state
  const instanceState = neru.getInstanceState();

  Object.keys(DATA_CENTER).forEach(async (region) => {
    const busyConv = await instanceState.hget(BUSY_CONV_STATE_KEY, region);
    if (busyConv) {
      let busyConvJson = JSON.parse(busyConv)
      let index = busyConvJson.findIndex((conv) => conv.conversationId == req.body.conversation_uuid)
      
      if (index > -1) {
        if (req.body.status && BUSY_STATE.includes(req.body.status.toLowerCase()) && (JSON.stringify(busyConvJson[index]['users']) != JSON.stringify([req.body.from, req.body.to]))) {  
          busyConvJson[index]['users'] = [req.body.from, req.body.to]
          await instanceState.hset(BUSY_CONV_STATE_KEY, { [region]: JSON.stringify(busyConvJson) });
          // Notify frontend
          notifyUsers(region)
        }
        else if (req.body.status && IDLE_STATE.includes(req.body.status.toLowerCase())) {
          let notifyUser = true
          if (!busyConvJson[index]['users']) {
            notifyUser = false
          }

          busyConvJson.splice(index, 1);
          await instanceState.hset(BUSY_CONV_STATE_KEY, { [region]: JSON.stringify(busyConvJson) });
          // Notify frontend
          if (notifyUser) {
            notifyUsers(region)
          }
        }
      }
    }
  })
  res.sendStatus(200);
});

app.listen(port, () => console.log(`Listening on port ${port}`)); 
