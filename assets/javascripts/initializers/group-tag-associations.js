import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "group-tag-associations",
  initialize() {
    withPluginApi((api) => {
      api.addModelSaveProperty("group", "associated_tags");
    });
  },
};
