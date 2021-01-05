import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "group-tag-associations",
  initialize() {
    withPluginApi("0.11.0", (api) => {
      api.modifyClass("model:group", {
        asJSON() {
          const attrs = this._super(...arguments);
          if (this.associated_tags) {
            attrs.associated_tags = this.associated_tags;
          }
          return attrs;
        },
      });
    });
  },
};
