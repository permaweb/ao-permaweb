import { Link } from "react-router-dom";

function HomePage() {
    return (
        <div>
            Welcome to the Permaweb!
            <Link to={"/about/"}>
                <div>About</div>
            </Link>
        </div>
    );
}

export default HomePage;
