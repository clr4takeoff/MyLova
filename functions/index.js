const axios = require('axios');
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { google } = require('googleapis');
const { CloudTasksClient } = require('@google-cloud/tasks');

const serviceAccount = require("./serviceAccountKey.json");
const tasksClient = new CloudTasksClient();

admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: "https://feelsbar-spin-off-31b2d-default-rtdb.firebaseio.com/"
});

const FCM_URL = "https://fcm.googleapis.com/v1/projects/feelsbar-spin-off-31b2d/messages:send";
const QUEUE_NAME = 'update-queue';
const LOCATION = 'us-central1';
const PROJECT_ID = 'feelsbar-spin-off-31b2d';

// 설정 가능한 전환 주기 (테스트용)
const SWITCH_INTERVAL_DAYS = 7;

// 한국 시간(KST) 기준 자정을 반환하는 함수
function getKSTMidnight(date = new Date()) {
    const KST_OFFSET = 9 * 60 * 60 * 1000; // 9시간 (한국 표준시)
    const utcTime = date.getTime(); // UTC 기준 밀리초 타임스탬프
    const kstTime = new Date(utcTime + KST_OFFSET); // KST 시간 계산
    return new Date(kstTime.getFullYear(), kstTime.getMonth(), kstTime.getDate()); // KST 자정으로 고정
}

// 디버깅용 KST 날짜 정보 출력 함수
function debugKST(date) {
    const kstDate = getKSTMidnight(date);
    const isEven = isEvenPeriod(kstDate);
    console.log(`[DEBUG] KST Date: ${kstDate}, Is Even Period: ${isEven}`);
    return { kstDate, isEven };
}

// 보조 함수: 특정 날짜의 isEvenPeriod 여부 계산
function calculateIsEven(referenceDate, targetDate) {
    const kstTarget = getKSTMidnight(targetDate);
    const kstReference = getKSTMidnight(referenceDate);
    const rawDifferenceInMilliseconds = kstTarget - kstReference;
    const differenceInDays = Math.floor(rawDifferenceInMilliseconds / (1000 * 60 * 60 * 24));
    const currentPeriod = Math.floor(differenceInDays / SWITCH_INTERVAL_DAYS);
    return currentPeriod % 2 === 0;
}


// 현재 주기가 짝수인지 홀수인지 확인하는 함수
function isEvenPeriod(referenceDate, targetDate = new Date()) {
    const kstNow = getKSTMidnight(targetDate); // 한국 시간 자정 기준
    const referenceKST = getKSTMidnight(referenceDate); // 사용자별 referenceDate
    const rawDifferenceInMilliseconds = kstNow - referenceDate; // 밀리초 차이 계산
    const differenceInDays = Math.floor(rawDifferenceInMilliseconds / (1000 * 60 * 60 * 24));
    const currentPeriod = Math.floor(differenceInDays / SWITCH_INTERVAL_DAYS);

    // 디버깅 로그 추가
    console.log(`[DEBUG] Target Date (KST - Midnight): ${kstNow}`);
    console.log(`[DEBUG] Reference Date (KST - Midnight): ${referenceDate}`);
    console.log(`[DEBUG] Raw Difference in Milliseconds: ${rawDifferenceInMilliseconds}`);
    console.log(`[DEBUG] Difference in Days (Floor): ${differenceInDays}`);
    console.log(`[DEBUG] Current Period: ${currentPeriod}`);
    console.log(`[DEBUG] Is Even Period: ${currentPeriod % 2 === 0}`);

    // 4일 뒤와 6일 뒤 날짜 및 isEvenPeriod 여부 계산 및 디버깅 출력
        const dateAfter6Days = new Date(referenceKST.getTime() + 6 * 24 * 60 * 60 * 1000); // referenceDate로부터 6일 뒤
        const dateAfter8Days = new Date(referenceKST.getTime() + 8 * 24 * 60 * 60 * 1000); // referenceDate로부터 8일 뒤

        const isEvenAfter4Days = calculateIsEven(referenceKST, dateAfter6Days);
        const isEvenAfter6Days = calculateIsEven(referenceKST, dateAfter8Days);

        console.log(`[DEBUG] 6일 뒤 날짜 (KST - Midnight): ${getKSTMidnight(dateAfter6Days).toISOString()}, Is Even Period: ${isEvenAfter4Days}`);
        console.log(`[DEBUG] 8일 뒤 날짜 (KST - Midnight): ${getKSTMidnight(dateAfter8Days).toISOString()}, Is Even Period: ${isEvenAfter6Days}`);


    return currentPeriod % 2 === 0;
}


// On database creation, schedule the task based on immediate/delayed logic
exports.scheduleCommentUpdate = functions.database.ref('/test/{username}/{diaryId}')
    .onCreate(async (snap, context) => {
        const diaryId = context.params.diaryId;
        const username = context.params.username;
        const userRef = admin.database().ref(`/users/${username}/referenceDate`);
        const diaryRef = admin.database().ref(`/test/${username}/${diaryId}`);

        let referenceDate;

        try {
            // 사용자 referenceDate 가져오기 또는 초기화
            const referenceSnapshot = await userRef.once('value');
            if (referenceSnapshot.exists()) {
                referenceDate = new Date(referenceSnapshot.val());
            } else {
                referenceDate = getKSTMidnight();
                await userRef.set(referenceDate.toISOString());
            }

            // Username 끝이 홀수인지 확인
            const lastChar = username.slice(-1);
            const isOddLastChar = !isNaN(lastChar) && parseInt(lastChar) % 2 !== 0;

            // 현재 주기가 짝수인지 확인
            const currentIsEven = isEvenPeriod(referenceDate);

            // 주기에 따라 반전된 로직 적용
            const isImmediate = currentIsEven ? !isOddLastChar : isOddLastChar;
            const isDelayed = !isImmediate;

            // Task 생성
            const payload = {
                username,
                diaryId,
                isDelayed,
            };

            const task = {
                httpRequest: {
                    httpMethod: 'POST',
                    url: `https://${LOCATION}-${PROJECT_ID}.cloudfunctions.net/sendNotificationOnCommentUpdate`,
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: Buffer.from(JSON.stringify(payload)).toString('base64')
                },
                scheduleTime: {
                    seconds: Math.floor(Date.now() / 1000) + (isImmediate ? 0 : 6 * 60 * 60)
                }
            };

            const queuePath = tasksClient.queuePath(PROJECT_ID, LOCATION, QUEUE_NAME);
            await tasksClient.createTask({ parent: queuePath, task });

            // Firebase에 isDelayed 값 기록
            await diaryRef.update({ isDelayed });

        } catch (error) {
            console.error("Error during task creation or database update:", error.message);
        }
    });


// Cloud Task triggers this function to update isCommented field and send notification
exports.sendNotificationOnCommentUpdate = functions.https.onRequest(async (req, res) => {
    const { username, diaryId } = req.body;

    if (!username || !diaryId) {
        console.error("[ERROR] Missing required parameters: username or diaryId.");
        return res.status(400).send("Bad Request: Missing username or diaryId.");
    }

    try {
        const diaryRef = admin.database().ref(`/test/${username}/${diaryId}`);

        // Fetch the diary data
        const diarySnapshot = await diaryRef.once('value');
        if (!diarySnapshot.exists()) {
            console.error(`[ERROR] Diary not found for username: ${username}, diaryId: ${diaryId}`);
            return res.status(404).send("Diary not found.");
        }

        const diaryData = diarySnapshot.val();
        const userToken = diaryData.deviceToken;

        if (!userToken) {
            console.error(`[ERROR] No deviceToken found for diaryId: ${diaryId}`);
            return res.status(400).send("User device token not found.");
        }

        // Update isCommented field in Firebase
        await diaryRef.update({
            isCommented: true
        });
        console.log(`[INFO] isCommented field updated for diaryId: ${diaryId}`);

        // Prepare the FCM message
        const message = {
            message: {
                token: userToken,
                notification: {
                    title: "새 답글 알림!",
                    body: "당신의 일기에 로바가 답글을 달았습니다."
                },
                data: {
                    isCommented: "true"
                }
            }
        };

        // Send notification via FCM
        try {
            const response = await axios.post(FCM_URL, message, {
                headers: {
                    'Authorization': `Bearer ${await getAccessToken()}`,
                    'Content-Type': 'application/json'
                }
            });
            console.log(`[INFO] Notification sent to user: ${userToken}`, response.data);
            res.status(200).send("Notification sent successfully.");
        } catch (fcmError) {
            console.error(`[ERROR] FCM notification failed for diaryId: ${diaryId}`, fcmError.response?.data || fcmError.message);
            res.status(500).send("Failed to send notification.");
        }
    } catch (error) {
        console.error(`[ERROR] An error occurred while processing diaryId: ${diaryId}`, error.message);
        res.status(500).send("An internal error occurred.");
    }
});


// Get Access Token for FCM
async function getAccessToken() {
    const auth = new google.auth.GoogleAuth({
        keyFile: "./serviceAccountKey.json",
        scopes: ["https://www.googleapis.com/auth/firebase.messaging"]
    });

    try {
        const accessToken = await auth.getAccessToken();
        return accessToken;
    } catch (error) {
        console.error("Error getting access token:", error);
        throw error;
    }
}