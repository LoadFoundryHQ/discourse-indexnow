export default {
  resource: "admin.adminPlugins.show",

  path: "/plugins",

  map() {
    this.route("indexnow-dashboard", { path: "indexnow" });
  },
};
