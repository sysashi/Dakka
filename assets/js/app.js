// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let Hooks = {}

Hooks.ChatAutoScroll = {
  mounted() {
    this.el.scrollTo(0, this.el.scrollHeight);
  },

  updated() {
    const pixelsBelowBottom =
      this.el.scrollHeight - this.el.clientHeight - this.el.scrollTop;

    if (pixelsBelowBottom < this.el.clientHeight * 0.3) {
      this.el.scrollTo(0, this.el.scrollHeight);
    }
  }
}

Hooks.Listings = {
  mounted() {
    let showOnline = this.el.getAttribute("data-show-online");
    let hideOnline = this.el.getAttribute("data-hide-online");

    this.handleEvent("show-seller-online", e => {
      this.el.querySelectorAll(`.${e.class}`).forEach(elem => {
        liveSocket.execJS(elem, showOnline);
      });
    })

    this.handleEvent("hide-seller-online", e => {
      this.el.querySelectorAll(`.${e.class}`).forEach(elem => {
        liveSocket.execJS(elem, hideOnline);
      });
    })
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {hooks: Hooks, params: {_csrf_token: csrfToken}})

window.addEventListener(`phx:highlight`, (e) => {
  let el = document.getElementById(e.detail.id)

  if(el) {
    el.classList.remove("highlighted");
    el.offsetHeight;
    el.classList.add("highlighted");
  }
})

window.addEventListener("phx:scroll-to-top", (e) => {
  window.scrollTo(0, 0)
})

document.querySelectorAll("input").forEach((input) => {
  input.addEventListener("clear-input", e => {
    input.value = "";
    let event = new Event("input", {bubbles: true});
    input.dispatchEvent(event);
  })
});

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket
