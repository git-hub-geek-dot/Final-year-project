const IST_TIME_ZONE = "Asia/Kolkata";

const applyProcessTimezone = () => {
  process.env.TZ = IST_TIME_ZONE;
};

module.exports = {
  IST_TIME_ZONE,
  applyProcessTimezone,
};
