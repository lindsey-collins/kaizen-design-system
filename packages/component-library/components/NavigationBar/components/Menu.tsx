import {
  IconButton,
  OffCanvas,
  OffCanvasContext,
} from "@kaizen/component-library"
const arrowLeftIcon = require("@kaizen/component-library/icons/arrow-left.icon.svg")
  .default
import * as React from "react"
import Media from "react-media"
import { MOBILE_QUERY } from "../constants"
import Link, { LinkProps } from "./Link"

const styles = require("./Menu.module.scss")

type MenuItem = {
  label: string
  url: string
  method?: "get" | "post" | "put" | "delete"
}

export type MenuProps = {
  header?: React.ReactElement<any>
  items: MenuItem[]
  automationId?: string
  heading: string
  mobileEnabled?: boolean
  active?: boolean
}

type State = {
  open: boolean
}

export default class Menu extends React.Component<MenuProps, State> {
  static displayName = "Menu"
  static defaultProps = {
    items: [],
    mobileEnabled: true,
  }
  rootRef = React.createRef<any>()

  state = { open: false }

  render() {
    const { children, automationId, heading, mobileEnabled } = this.props

    return (
      <Media query={MOBILE_QUERY}>
        {(matches: boolean) =>
          mobileEnabled && matches ? (
            <React.Fragment>
              <OffCanvasContext.Consumer>
                {({ toggleVisibleMenu }) => (
                  <Link
                    text={heading}
                    href="#"
                    onClick={() => toggleVisibleMenu(heading)}
                    hasMenu
                  />
                )}
              </OffCanvasContext.Consumer>
              {this.renderOffCanvas()}
            </React.Fragment>
          ) : (
            <React.Fragment>
              <Link
                ref={this.rootRef}
                text={heading}
                href="#"
                onClick={e => this.toggle(e)}
                aria-expanded={this.state.open}
                data-automation-id={automationId}
                hasMenu
              />
              {this.state.open && this.renderMenu()}
            </React.Fragment>
          )
        }
      </Media>
    )
  }

  toggle = (e: React.SyntheticEvent<HTMLAnchorElement> | MouseEvent) => {
    const open = !this.state.open
    this.setState({ open })
  }

  renderMenu() {
    return <ul className={styles.menu}>{this.props.items.map(this.renderMenuItem)}</ul>
  }

  renderOffCanvas() {
    const { items, heading } = this.props
    const links = items.map(this.renderOffCanvasMenuItem)

    return (
      <OffCanvas
        links={links}
        heading={heading ? heading : "Menu"}
        headerComponent={this.renderBackButton()}
        menuId={heading}
      />
    )
  }

  renderBackButton() {
    return (
      <OffCanvasContext.Consumer>
        {({ toggleVisibleMenu }) => (
          <IconButton
            label="Back"
            icon={arrowLeftIcon}
            onClick={() => toggleVisibleMenu(this.props.heading)}
            reversed
          />
        )}
      </OffCanvasContext.Consumer>
    )
  }

  renderOffCanvasMenuItem = (item: MenuItem, index: number) => (
    <Link key={index} text={item.label} href={item.url} />
  )

  renderMenuItem = (item: MenuItem, index: number) => {
    const { label, url, method } = item

    if (method && method !== "get") {
      return (
        // HTML forms only accept POST. We use a hidden `_method` input as a convention for emulating other HTTP verbs.
        // This behaviour is the same as what is implemented by UJS and supported by Rails:
        // https://github.com/rails/jquery-ujs
        <form method="post" action={url}>
          <input name="_method" value={method} type="hidden" />
          <button type="submit" className={styles.menuItem}>
            {label}
          </button>
        </form>
      )
    }

    return (
      <a href={url} className={styles.menuItem} tabIndex={0}>
        {label}
      </a>
    )
  }

  componentDidMount() {
    document.addEventListener("click", this.clickDocument)
  }

  componentWillUnmount() {
    document.removeEventListener("click", this.clickDocument)
  }

  clickDocument = (e: MouseEvent) => {
    // We can't just stopPropagation of click events in the menu, because a
    // click in this menu may also need to dismiss another open menu.
    if (
      this.state.open &&
      this.rootRef.current &&
      !(e.target instanceof Node && this.rootRef.current.contains(e.target))
    ) {
      this.toggle(e)
    }
  }
}
