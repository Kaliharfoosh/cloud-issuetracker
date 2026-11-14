const express = require("express");
const issueController = require("../controllers/issues");

const router = express.Router();

router.get("/", issueController.listIssues);
router.get("/count", issueController.countIssues);
router.post("/", issueController.createIssue);
router.patch("/:id/status", issueController.updateIssueStatus);

module.exports = router;
